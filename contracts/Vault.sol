// contracts/Vault.sol
pragma solidity ^0.5.8;

import "./vault-modules/VoteManagement.sol";
import "./celo/common/UsingRegistry.sol";
import "./celo/common/libraries/LinkedList.sol";

contract Vault is UsingRegistry, VoteManagement {
    using LinkedList for LinkedList.List;

    address public proxyAdmin;
    ILockedGold public lockedGold;
    LinkedList.List public pendingWithdrawals;

    function initialize(
        address registry_,
        address archive_,
        address owner_,
        address proxyAdmin_
    ) public payable initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
        VoteManagement.initialize(archive_, getElection());
        Ownable.initialize(owner_);

        lockedGold = getLockedGold();

        _setProxyAdmin(proxyAdmin_);
        getAccounts().createAccount();
        deposit();
    }

    function setProxyAdmin(address admin) external onlyOwner {
        _setProxyAdmin(admin);
    }

    function _setProxyAdmin(address admin) internal {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function getBalances() public view returns (uint256, uint256) {
        uint256 nonvoting = lockedGold.getAccountNonvotingLockedGold(
            address(this)
        );
        uint256 voting = lockedGold
            .getAccountTotalLockedGold(address(this))
            .sub(nonvoting);

        return (voting, nonvoting);
    }

    // Fallback function so the vault can accept incoming withdrawal/reward transfers
    function() external payable {}

    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than zero");

        // Immediately lock the deposit
        lockedGold.lock.value(msg.value)();
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

            return _initiateWithdrawal(amount, true);
        }

        // If the nonVoting balance is sufficient, we can directly unlock the specified amount
        if (nonVotingBalance >= amount) {
            return _initiateWithdrawal(amount, true);
        }

        // Proceed with revoking votes across the groups to satisfy the specified withdrawal amount
        uint256 revokeAmount = amount.sub(nonVotingBalance);
        uint256 revokeDiff = revokeAmount.sub(
            _revokeVotesProportionatelyForGroups(revokeAmount)
        );

        _initiateWithdrawal(amount.sub(revokeDiff), true);
    }

    /**
     * @notice Creates a pending withdrawal and generates a hash for verification
     */
    function _initiateWithdrawal(uint256 amount, bool forOwner) internal {
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

        address withdrawalRecipient = forOwner ? owner() : manager;

        // Generate a hash for withdrawal-time verification
        pendingWithdrawals.push(
            keccak256(
                abi.encodePacked(
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
        _updateManagerRewardsForAllGroups();

        // Withdraw the manager's pending withdrawal balance
        _initiateWithdrawal(managerRewards, false);

        Manager(manager).deregisterVault();

        delete manager;
        delete managerCommission;
        delete managerRewards;
    }
}
