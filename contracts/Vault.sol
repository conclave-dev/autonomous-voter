// contracts/Vault.sol
pragma solidity ^0.5.8;

import "./vault-modules/VoteManagement.sol";
import "./celo/common/UsingRegistry.sol";
import "./Archive.sol";

contract Vault is UsingRegistry, VoteManagement {
    address public proxyAdmin;

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

    // Fallback function so the vault can accept incoming withdrawal/reward transfers
    function() external payable {}

    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than zero");

        // Immediately lock the deposit
        lockedGold.lock.value(msg.value)();
    }

    // Perform funds unlock and save it as pending withdrawal record
    function _initiateWithdrawal(uint256 amount) internal {
        // At this point, it should now have enough golds to be unlocked
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

    /**
     * @notice Initiate funds withdrawal
     * @param amount The amount of funds to be withdrawn
     */
    function initiateWithdrawal(uint256 amount) external onlyOwner {
        (uint256 votingBalance, uint256 nonVotingBalance) = getBalances();
        uint256 totalBalance = votingBalance.add(nonVotingBalance);

        if (manager != address(0)) {
            _updateManagerRewardsForAllGroups();

            // Check if the withdrawal amount specified is within the limit
            // (after considering manager rewards and minimum required funds)
            require(
                amount > 0 &&
                    amount <=
                    totalBalance.sub(managerRewards).sub(
                        managerMinimumBalanceRequirement
                    ),
                "Invalid withdrawal amount specified"
            );
        } else if (amount == totalBalance) {
            // Revoke all group votes to perform full balance withdrawal
            if (votingBalance > 0) {
                _revokeVotesEntirelyForGroups();
            }

            return _initiateWithdrawal(amount);
        }

        // If the nonVoting balance is sufficient, we can directly unlock the specified amount
        if (nonVotingBalance >= amount) {
            return _initiateWithdrawal(amount);
        }

        // Proceed with revoking votes across the groups to satisfy the specified withdrawal amount
        uint256 revokeAmount = amount.sub(nonVotingBalance);
        uint256 revokeDiff = revokeAmount.sub(
            _revokeVotesProportionatelyForGroups(revokeAmount)
        );

        _initiateWithdrawal(amount.sub(revokeDiff));
    }
}
