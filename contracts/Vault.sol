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
        (uint256 nonVotingBalance, uint256 votingBalance) = getBalances();
        uint256 totalBalance = votingBalance.add(nonVotingBalance);

        if (manager != address(0)) {
            _updateManagerRewardsForAllGroups();

            // Check if the withdrawal amount specified is within the limit
            // (after considering manager rewards and minimum required funds)
            require(
                amount > 0 &&
                    amount <=
                    totalBalance.sub(managerRewards).sub(managerMinimumFunds),
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

    /**
     * @notice Cancel an existing pending withdrawal record
     * @param index Index of the pending withdrawal record to be cancelled
     * @param amount The amount of funds of the pending withdrawal to be cancelled
     */
    function cancelWithdrawal(uint256 index, uint256 amount)
        external
        onlyOwner
    {
        require(amount > 0, "Invalid amount specified");

        (uint256[] memory amounts, uint256[] memory timestamps) = lockedGold
            .getPendingWithdrawals(address(this));

        require(index < timestamps.length, "Index out-of-bound");
        require(amounts[index] >= amount, "Invalid amount specified");

        bytes32 encodedWithdrawal = keccak256(
            abi.encode(owner(), amounts[index], timestamps[index])
        );
        require(
            pendingWithdrawals.contains(encodedWithdrawal) == true,
            "Invalid withdrawal specified"
        );

        lockedGold.relock(index, amount);
    }

    /**
     * @notice Finalize completed/released withdrawal records and transfer the funds to the owner
     */
    function withdraw() external onlyOwner {
        (uint256[] memory amounts, uint256[] memory timestamps) = lockedGold
            .getPendingWithdrawals(address(this));

        // Iterate through the withdrawal lists.
        // Note that we need to fully iterate it since withdrawal with further timestamp can be located in front
        // as they're not always sorted due to shifting on records deletion
        uint256 totalWithdrawalAmount = 0;
        for (uint256 i = 0; i < timestamps.length; i++) {
            require(timestamps[i] < now, "Withdrawal is not yet available");
            // Crosscheck with our local records
            bytes32 encodedWithdrawal = keccak256(
                abi.encode(owner(), amounts[i], timestamps[i])
            );
            if (pendingWithdrawals.contains(encodedWithdrawal) == true) {
                totalWithdrawalAmount = totalWithdrawalAmount.add(amounts[i]);
                pendingWithdrawals.remove(encodedWithdrawal);
                lockedGold.withdraw(i);
            }
        }

        // Forward the withdrawn funds to the vault owner
        msg.sender.transfer(totalWithdrawalAmount);
    }
}
