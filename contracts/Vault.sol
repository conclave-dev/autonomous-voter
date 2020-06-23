// contracts/Vault.sol
pragma solidity ^0.5.8;

import "./vault-modules/VoteManagement.sol";
import "./celo/common/UsingRegistry.sol";
import "./Archive.sol";
import "./celo/common/libraries/LinkedList.sol";

contract Vault is UsingRegistry, VoteManagement {
    using LinkedList for LinkedList.List;

    address public proxyAdmin;
    LinkedList.List pendingWithdrawals;

    function initialize(
        address registry_,
        address archive_,
        address owner_,
        address proxyAdmin_
    ) public payable initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
        Ownable.initialize(owner_);

        proxyAdmin = proxyAdmin_;
        archive = Archive(archive_);

        setRegistryContracts();

        getAccounts().createAccount();
        deposit();
    }

    function setRegistryContracts() internal {
        election = getElection();
        lockedGold = getLockedGold();
    }

    function setProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than zero");

        // Immediately lock the deposit
        lockedGold.lock.value(msg.value)();
    }

    // Gets the Vault's locked gold amount (both voting and nonvoting)
    function getBalances() public view returns (uint256, uint256) {
        uint256 nonvoting = lockedGold.getAccountNonvotingLockedGold(
            address(this)
        );
        uint256 voting = lockedGold
            .getAccountTotalLockedGold(address(this))
            .sub(nonvoting);

        return (voting, nonvoting);
    }

    function _findLesserAndGreater(
        address group,
        uint256 groupVotes,
        bool isRevoke
    ) internal view returns (address, address) {
        (address[] memory groups, uint256[] memory votes) = election
            .getTotalVotesForEligibleValidatorGroups();
        address lesser = address(0);
        address greater = address(0);

        // Get the current totalVote count for the specified group
        uint256 totalVotes = election.getTotalVotesForGroupByAccount(
            group,
            address(this)
        );
        if (isRevoke) {
            totalVotes = totalVotes.sub(groupVotes);
        } else {
            totalVotes = totalVotes.add(groupVotes);
        }

        // Look for the adjacent groups with less and more votes, respectively
        for (uint256 i = 0; i < groups.length; i = i.add(1)) {
            if (groups[i] != group) {
                if (votes[i] <= totalVotes) {
                    lesser = groups[i];
                    break;
                }
                greater = groups[i];
            }
        }

        return (lesser, greater);
    }

    function revokeVotesEntirelyForGroups() internal {
        address[] memory groups = election.getGroupsVotedForByAccount(
            address(this)
        );

        for (uint256 i = 0; i < groups.length; i += 1) {
            uint256 groupActiveVotes = election.getActiveVotesForGroupByAccount(
                groups[i],
                address(this)
            );
            uint256 groupPendingVotes = election
                .getPendingVotesForGroupByAccount(groups[i], address(this));

            if (groupPendingVotes > 0) {
                (address lesser, address greater) = _findLesserAndGreater(
                    groups[i],
                    groupPendingVotes,
                    true
                );

                revokePending(groups[i], groupPendingVotes, lesser, greater, i);
            }

            if (groupActiveVotes > 0) {
                (address lesser, address greater) = _findLesserAndGreater(
                    groups[i],
                    groupActiveVotes,
                    true
                );

                revokeActive(groups[i], groupActiveVotes, lesser, greater, i);
            }
        }
    }

    function revokeVotesProportionatelyForGroups(uint256 amount)
        internal
        returns (uint256)
    {
        address[] memory groups = election.getGroupsVotedForByAccount(
            address(this)
        );
        uint256 totalVotes = election.getTotalVotesByAccount(address(this));
        uint256 amountRevoked = 0;

        // Withdraw from voting balance
        // Iterate over groups and revoke votes (pending, then active)
        for (uint256 i = 0; i < groups.length; i += 1) {
            uint256 groupActiveVotes = election.getActiveVotesForGroupByAccount(
                groups[i],
                address(this)
            );
            uint256 groupPendingVotes = election
                .getPendingVotesForGroupByAccount(groups[i], address(this));

            // First, get total group votes by adding active and pending votes
            // Multiply by the amount to be removed, then divide by total votes to get the removal amount
            // NOTE: SafeMath rounds down and this does not account for that but you get the idea -
            //  can use Fixidity or revoke the remainder at the end from the group with the most votes
            uint256 groupTotalVotes = groupActiveVotes.add(groupPendingVotes);

            // Calculate the amount votes to revoke from the group
            uint256 groupRevokeAmount = groupTotalVotes.mul(amount).divide(
                totalVotes
            );

            // There should never be an instance where the group's revoke amount is greater than the remaining revoke amount
            assert(amount >= groupRevokeAmount);

            amountRevoked = amountRevoked.add(groupRevokeAmount);

            // Get the addresses of the adjacent groups with lesser and greater votes AFTER revoking
            (address lesser, address greater) = _findLesserAndGreater(
                groups[i],
                groupRevokeAmount,
                true
            );

            // If the group's pending votes is greater than 0, revoke whatever is available
            if (groupPendingVotes > 0) {
                if (groupPendingVotes >= amount) {
                    // Revoke the withdrawal amount, as it is covered by pending
                    revokePending(groups[i], amount, lesser, greater, i);

                    // Proceed to next group, since we are done here
                    continue;
                } else {
                    // Revoke only the pending votes, as it does not cover the withdrawal amount
                    revokePending(
                        groups[i],
                        groupPendingVotes,
                        lesser,
                        greater,
                        i
                    );
                }

                // If groupPendingVotes does not cover the amount to be revoked for this group, then calculate the amount of
                // active votes that need to be revoked
                groupRevokeAmount = groupRevokeAmount.sub(groupPendingVotes);

                // @NOTE: We need to run _findLesserAndGreater again since the group addresses are ordered by *total* votes.
                // Since we've just revoked pending votes, the total will change and we'll need to re-compute those values
                (
                    address updatedLesser,
                    address updatedGreater
                ) = _findLesserAndGreater(groups[i], groupRevokeAmount, true);

                lesser = updatedLesser;
                greater = updatedGreater;
            }

            // Revoke the remaining amount from the group's active votes
            revokeActive(groups[i], groupRevokeAmount, lesser, greater, i);
        }

        return amountRevoked;
    }

    function updateManagerRewardsForAllGroups() internal {
        address[] memory groups = election.getGroupsVotedForByAccount(
            address(this)
        );

        for (uint256 i = 0; i < groups.length; i += 1) {
            // Update manager rewards
            // https://github.com/conclave-dev/autonomous-voter/blob/2343ca0cb8ded807dfae71138d894e8cfe02e983/contracts/vault-modules/VoteManagement.sol#L69
            updateManagerRewardsForGroup(groups[i]);
        }
    }

    function _initiateWithdrawal(uint256 amount) internal {
        lockedGold.unlock(amount);

        // Fetch the last initiated withdrawal and track it locally
        (uint256[] memory amounts, uint256[] memory timestamps) = lockedGold
            .getPendingWithdrawals(address(this));

        pendingWithdrawals.push(
            keccak256(
                abi.encode(
                    owner(),
                    amounts[amounts.length - 1],
                    timestamps[timestamps.length - 1]
                )
            )
        );
    }

    function initiateWithdrawal(uint256 amount) external onlyOwner {
        (uint256 votingBalance, uint256 nonvotingBalance) = getBalances();
        uint256 totalBalance = votingBalance.add(nonvotingBalance);

        require(amount <= totalBalance);

        // If a manager is set, check if the post-withdrawal balance is above their minimum
        // See `manager` here:
        // https://github.com/conclave-dev/autonomous-voter/blob/2343ca0cb8ded807dfae71138d894e8cfe02e983/contracts/vault-modules/VoteManagement.sol#L21
        if (manager != address(0)) {
            // 1. Settle rewards owed to the manager (must protect our users - includes managers - first)
            updateManagerRewardsForAllGroups();

            // 2. Ensure that the amount is less than the "withdrawal balance"
            // withdrawableBalance = (totalBalance - managerRewards)
            // See `managerRewards` here:
            // https://github.com/conclave-dev/autonomous-voter/blob/2343ca0cb8ded807dfae71138d894e8cfe02e983/contracts/vault-modules/VoteManagement.sol#L23
            uint256 withdrawableBalance = totalBalance.sub(managerRewards);
            require(
                amount <= withdrawableBalance,
                "Amount greater than withdrawable balance"
            );

            // Require post-withdraw balance (withdrawableBalance - amount) is GTE manager's minimum balance requirement
            uint256 postWithdrawalBalance = withdrawableBalance.sub(amount);
            require(
                postWithdrawalBalance >=
                    Manager(manager).minimumManageableBalanceRequirement(),
                "Post-withdrawal balance will be below manager's minimum balance requirement"
            );
        } else {
            // A full balance withdrawal would only be possible if no manager were present
            // If the withdrawal amount is equal to the total balance, then revoke all votes from groups and unlock entire balance
            if (amount == totalBalance) {
                // Revoke votes for groups if any
                if (votingBalance > 0) {
                    revokeVotesEntirelyForGroups();

                    assert(election.getTotalVotesByAccount(address(this)) == 0);
                }

                return _initiateWithdrawal(amount);
            }
        }

        // If nonvotingBalance covers the withdrawal amount then finish here
        if (nonvotingBalance >= amount) {
            return _initiateWithdrawal(amount);
        }

        // Else, calculate the votes that need to be revoked from groups to cover
        // the amount needed
        uint256 revokeAmount = amount.sub(nonvotingBalance);

        revokeVotesProportionatelyForGroups(revokeAmount);

        return _initiateWithdrawal(amount);
    }
}
