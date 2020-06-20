// contracts/Vault.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../Archive.sol";
import "../VaultManager.sol";
import "../celo/governance/interfaces/IElection.sol";
import "../celo/governance/interfaces/ILockedGold.sol";
import "../celo/common/libraries/AddressLinkedList.sol";
import "../celo/common/libraries/LinkedList.sol";
import "../celo/common/FixidityLib.sol";

contract VoteManagement is Ownable {
    using SafeMath for uint256;
    using LinkedList for LinkedList.List;
    using FixidityLib for FixidityLib.Fraction;

    Archive public archive;
    IElection public election;
    ILockedGold public lockedGold;

    address public manager;
    uint256 public managerCommission;
    LinkedList.List public managerPendingWithdrawals;
    LinkedList.List public groups;
    mapping(address => uint256) public activeVotesByGroup;

    modifier onlyVoteManager() {
        require(msg.sender == manager, "Not the voting vault manager");
        _;
    }

    // This modifier is sparingly applied to voting-related methods callable by the owner
    // and the manager. Generally, we don't want the owner to influence the vault's voting
    // groups, unless it is their intent to remove the voting vault manager.
    modifier onlyOwnerOrVoteManager() {
        require(
            msg.sender == owner() || msg.sender == manager,
            "Not the owner or voting vault manager"
        );
        _;
    }

    modifier onlyGroupWithVotes(address group) {
        require(_groupsContains(group) == true, "Group does not have votes");
        _;
    }

    modifier postRevokeCleanup(address group) {
        // Execute function first
        _;

        // Cleans up after vote-revoking method calls, by removing the group if it doesn't have votes
        if (
            election.getTotalVotesForGroupByAccount(group, address(this)) == 0
        ) {
            delete activeVotesByGroup[group];

            _groupsRemove(group);
        }
    }

    // Gets the Vault's locked gold amount (both voting and nonvoting)
    function getManageableBalance() external view returns (uint256) {
        return lockedGold.getAccountTotalLockedGold(address(this));
    }

    // Gets the Vault's nonvoting locked gold amount
    function getNonvotingBalance() public view returns (uint256) {
        return lockedGold.getAccountNonvotingLockedGold(address(this));
    }

    function getVoteManager() external view returns (address, uint256) {
        return (manager, managerCommission);
    }

    function setVoteManager(VaultManager manager_) external onlyOwner {
        require(
            archive.hasVaultManager(manager_.owner(), address(manager_)),
            "Voting vault manager_ is invalid"
        );
        require(manager == address(0), "Voting vault manager_ already exists");

        manager_.registerVault();

        manager = address(manager_);
        managerCommission = manager_.rewardSharePercentage();
    }

    /**
     * @notice Removes a voting vault manager
     */
    function removeVoteManager() external onlyOwner {
        require(manager != address(0), "Voting vault manager does not exist");
        require(
            groups.getKeys().length == 0,
            "Group votes have not been revoked"
        );

        VaultManager(manager).deregisterVault();

        manager = address(0);
    }

    /**
     * @notice Calculates the voting vault manager's rewards for a group
     * @param group A validator group with active votes placed by the voting vault manager
     * @return Manager's reward amount
     */
    function calculateVoteManagerRewards(address group)
        public
        view
        returns (uint256)
    {
        FixidityLib.Fraction memory activeVotes = FixidityLib.newFixed(
            election.getActiveVotesForGroupByAccount(group, address(this))
        );
        FixidityLib.Fraction memory activeVotesWithoutRewards = FixidityLib
            .newFixed(activeVotesByGroup[group]);
        FixidityLib.Fraction memory rewards = FixidityLib.subtract(
            activeVotes,
            activeVotesWithoutRewards
        );
        FixidityLib.Fraction memory rewardsPercent = FixidityLib.divide(
            rewards,
            FixidityLib.newFixed(100)
        );

        // rewards(Accrued) = activeVotes (Celo) - activeVotesWithoutRewards (local)
        // votingManagerRewards = (rewards / 100) * rewardSharePercentage
        return
            FixidityLib
                .multiply(
                rewardsPercent,
                FixidityLib.newFixed(managerCommission)
            )
                .fromFixed();
    }

    /**
     * @notice Distributes a voting vault manager's rewards
     * @param group A validator group with active votes placed by the voting vault manager
     * @param adjacentGroupWithLessVotes An eligible validator group, adjacent to group, with less votes
     * @param adjacentGroupWithMoreVotes An eligible validator group, adjacent to group, with more votes
     * @param accountGroupIndex Index of the group for this vault's account
     */
    function distributeVoteManagerRewards(
        address group,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) public onlyOwnerOrVoteManager onlyGroupWithVotes(group) {
        uint256 vaultManagerRewards = calculateVoteManagerRewards(group);

        // Revoke active votes equal to the manager's rewards, so that they can be unlocked and tracked
        election.revokeActive(
            group,
            vaultManagerRewards,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );

        // Unlock tokens equal to the manager's rewards to initiate withdrawal
        lockedGold.unlock(vaultManagerRewards);

        // Retrieve the Vault's pending withdrawals (manager's rewards should be the last element)
        (
            uint256[] memory pendingWithdrawalValues,
            uint256[] memory pendingWithdrawalTimestamps
        ) = lockedGold.getPendingWithdrawals(address(this));

        // Add voting manager rewards to the pendingWithdrawals list
        managerPendingWithdrawals.push(
            keccak256(
                abi.encode(
                    manager,
                    pendingWithdrawalValues[pendingWithdrawalValues.length - 1],
                    pendingWithdrawalTimestamps[pendingWithdrawalTimestamps
                        .length - 1]
                )
            )
        );

        // Set group's activeVotes to current active votes (should be equal after reward distribution)
        activeVotesByGroup[group] = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );
    }

    /**
     * @notice Revokes a group's votes and removes them from state
     * @param group Groups with votes (must maintain the same order as that of the vault account)
     * @param adjacentGroupWithLessVotes List of adjacent eligible validator groups with less votes
     * @param adjacentGroupWithMoreVotes List of adjacent eligible validator groups with more votes
     * @param accountGroupIndex Index of the group for this vault's account
     */
    function revokeAll(
        address group,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) external onlyOwnerOrVoteManager onlyGroupWithVotes(group) {
        uint256 pendingVotes = election.getPendingVotesForGroupByAccount(
            group,
            address(this)
        );

        // If there are pending votes for this group, revoke them
        if (pendingVotes > 0) {
            _revokePending(
                group,
                pendingVotes,
                adjacentGroupWithLessVotes,
                adjacentGroupWithMoreVotes,
                accountGroupIndex
            );
        }

        _revokeActive(
            group,
            activeVotesByGroup[group],
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );
    }

    /**
     * @notice Adds votes to an eligible validator group
     * @param group An eligible validator group
     * @param amount The amount of votes to place for this group
     * @param adjacentGroupWithLessVotes List of adjacent eligible validator groups with less votes
     * @param adjacentGroupWithMoreVotes List of adjacent eligible validator groups with more votes
     */
    function vote(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes
    ) external onlyVoteManager {
        // Validates group eligibility, sufficient vote amount, and group voting limit
        election.vote(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes
        );

        if (_groupsContains(group) == true) {
            return;
        }

        _groupsPush(group);
    }

    /**
     * @notice Activates pending votes for a validator group that this vault is currently voting for
     * @param group A validator group
     */
    function activate(address group)
        public
        onlyVoteManager
        onlyGroupWithVotes(group)
    {
        // Save pending votes amount before activation attempt
        uint256 pendingVotes = election.getPendingVotesForGroupByAccount(
            group,
            address(this)
        );

        // activate validates pending vote epoch and non-zero vote amount
        election.activate(group);

        // Increment activeVotes by activated pending votes instead of
        // Celo active votes in order to retain reward accrual difference
        activeVotesByGroup[group] = activeVotesByGroup[group] + pendingVotes;
    }

    /**
     * @notice Iterates over voted groups and activates pending votes that are available
     */
    function activateAll() external onlyVoteManager {
        address[] memory groups_ = _groupsGetKeys();

        for (uint256 i = 0; i < groups_.length; i += 1) {
            // Call activate with group if it has activatable pending votes
            if (
                election.hasActivatablePendingVotes(
                    address(this),
                    groups_[i]
                ) == true
            ) {
                activate(groups_[i]);
            }
        }
    }

    /**
     * @notice Revokes active votes for a validator group that this vault is currently voting for
     * @param group A validator group
     * @param amount The amount of active votes to revoke
     * @param adjacentGroupWithLessVotes List of adjacent eligible validator groups with less votes
     * @param adjacentGroupWithMoreVotes List of adjacent eligible validator groups with more votes
     * @param accountGroupIndex Index of the group for this vault's account
     */
    function revokeActive(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) external onlyVoteManager onlyGroupWithVotes(group) {
        _revokeActive(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );
    }

    /**
     * @notice Revokes pending votes for a validator group that this vault is currently voting for
     * @param group A validator group
     * @param amount The amount of pending votes to revoke
     * @param adjacentGroupWithLessVotes List of adjacent eligible validator groups with less votes
     * @param adjacentGroupWithMoreVotes List of adjacent eligible validator groups with more votes
     * @param accountGroupIndex Index of the group for this vault's account
     */
    function revokePending(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) external onlyVoteManager onlyGroupWithVotes(group) {
        _revokePending(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );
    }

    // Internal method to allow the owner to manipulate group votes for certain operations
    // Primarily called by the vault manager-only method of the same name without leading underscore
    function _revokeActive(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) internal postRevokeCleanup(group) {
        uint256 activeVotesAfterRewardDistribution = (election
            .getActiveVotesForGroupByAccount(group, address(this)) -
            calculateVoteManagerRewards(group));

        // Communicate that the amount must be less than post-reward distribution active votes
        require(
            activeVotesAfterRewardDistribution >= amount,
            "Amount is greater than active votes remaining after manager reward distribution"
        );

        // Settles rewards owed to the vault manager and brings locally-stored
        // activeVotes to parity with Celo activeVotes
        distributeVoteManagerRewards(
            group,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );

        // Validates group and revoke amount (cannot be zero or greater than active votes)
        election.revokeActive(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );

        activeVotesByGroup[group] = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );
    }

    // Internal method to allow the owner to manipulate group votes for certain operations
    // Primarily called by the vault manager-only method of the same name without leading underscore
    function _revokePending(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) internal postRevokeCleanup(group) {
        // Validates group and revoke amount (cannot be zero or greater than pending votes)
        election.revokePending(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );
    }

    // Helper methods for utilizing AddressLinkedList without overshadowing LinkedList.List
    function _groupsPush(address group) internal {
        groups.push(AddressLinkedList.toBytes(group));
    }

    function _groupsContains(address group) internal view returns (bool) {
        return groups.contains(AddressLinkedList.toBytes(group));
    }

    function _groupsRemove(address group) internal {
        groups.remove(AddressLinkedList.toBytes(group));
    }

    function _groupsGetKeys() internal view returns (address[] memory) {
        return AddressLinkedList.getKeys(groups);
    }
}
