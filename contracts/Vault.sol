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

        require(
            amount > 0 && amount <= totalBalance,
            "Invalid withdrawal amount"
        );

        if (manager != address(0)) {
            _updateManagerRewardsForAllGroups();

            // Check if the withdrawal amount specified is within the limit
            // (after considering manager rewards and minimum required funds)
            require(
                amount <=
                    totalBalance.sub(managerRewards).sub(
                        managerMinimumBalanceRequirement
                    ),
                "Specified withdrawal amount exceeds the withdrawable limit"
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
     * @notice Creates a pending withdrawal and generates a hash for verification
     */
    function _initiateWithdrawal(uint256 amount) internal {
        // @TODO: Consider creating 2 separate "initiate withdrawal" methods in order to
        // thoroughly validate based on whether it's the owner or manager

        // Only the owner or vote manager can call this method
        require(
            msg.sender == owner() || msg.sender == manager,
            "Not authorized"
        );

        lockedGold.unlock(amount);

        // Fetch pending withdrawals (last element should be the pending withdrawal
        // for the amount that was unlocked above)
        (uint256[] memory amounts, uint256[] memory timestamps) = lockedGold
            .getPendingWithdrawals(address(this));

        address withdrawalRecipient = msg.sender == owner() ? owner() : manager;

        // Generate a hash for withdrawal-time verification
        pendingWithdrawals.push(
            keccak256(
                abi.encode(
                    // Account that should be receiving the withdrawal funds
                    withdrawalRecipient,
                    // Pending withdrawal amount
                    amounts[amounts.length - 1],
                    // Pending withdrawal timestamp
                    timestamps[timestamps.length - 1]
                )
            )
        );
    }

    /**
     * @notice Sets the vote manager
     */
    function setVoteManager(Manager manager_) external onlyOwner {
        require(
            archive.hasManager(manager_.owner(), address(manager_)),
            "Vote manager is invalid"
        );
        require(manager == address(0), "Vote manager already exists");

        manager_.registerVault();

        manager = address(manager_);
        managerCommission = manager_.commission();
    }

    /**
     * @notice Removes the vote manager
     */
    function removeVoteManager() external onlyOwner {
        require(manager != address(0), "Vote manager does not exist");

        // Ensure that all outstanding manager rewards are accounted for
        updateManagerRewardsForGroups();

        // Withdraw the manager's pending withdrawal balance
        _initiateWithdrawal(managerRewards);

        Manager(manager).deregisterVault();

        delete manager;
        delete managerCommission;
        delete managerRewards;
    }
}
