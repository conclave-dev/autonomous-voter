// contracts/Vault.sol
pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./celo/common/UsingRegistry.sol";
import "./Archive.sol";
import "./VaultManager.sol";
import "./celo/common/libraries/AddressLinkedList.sol";

contract Vault is UsingRegistry {
    using SafeMath for uint256;
    using AddressLinkedList for LinkedList.List;

    struct VaultManagers {
        VotingVaultManager voting;
        VaultManagerReward[] rewards;
    }

    // Rewards set aside for a manager - cannot be withdrawn by the owner, unless it expires
    // TODO: Add reward withdrawal expiry logic
    struct VaultManagerReward {
        address recipient;
        uint256 amount;
        uint256 timestamp;
    }

    struct VotingVaultManager {
        address contractAddress;
        // The voting vault manager's reward share percentage when they were added
        // This protects the vault owner from increases by the voting vault manager
        uint256 rewardSharePercentage;
    }

    struct Votes {
        mapping(address => uint256) activeVotesWithoutRewards;
        LinkedList.List groups;
    }

    Archive private archive;
    IElection private election;
    ILockedGold private lockedGold;
    VaultManagers private vaultManagers;
    Votes private votes;

    address public proxyAdmin;

    modifier onlyVotingVaultManager() {
        require(
            msg.sender == vaultManagers.voting.contractAddress,
            "Not the voting vault manager"
        );
        _;
    }

    // This modifier is sparingly applied to voting-related methods callable by the owner
    // and the manager. Generally, we don't want the owner to influence the vault's voting
    // groups, unless it is their intent to remove the voting vault manager.
    modifier onlyOwnerOrVotingVaultManager() {
        require(
            msg.sender == owner() ||
                msg.sender == vaultManagers.voting.contractAddress,
            "Not the owner or voting vault manager"
        );
        _;
    }

    modifier onlyGroupWithVotes(address group) {
        require(
            votes.groups.contains(group) == true,
            "Group does not have votes"
        );
        _;
    }

    modifier postRevokeCleanup(address group) {
        // Execute function first
        _;

        // Cleans up after vote-revoking method calls, by removing the group if it doesn't have votes
        if (
            election.getTotalVotesForGroupByAccount(group, address(this)) == 0
        ) {
            delete votes.activeVotesWithoutRewards[group];

            votes.groups.remove(group);
        }
    }

    function initialize(
        address registry_,
        Archive archive_,
        address owner_,
        address admin
    ) public payable initializer {
        archive = archive_;
        proxyAdmin = admin;

        UsingRegistry.initializeRegistry(msg.sender, registry_);
        Ownable.initialize(owner_);
        getAccounts().createAccount();
        election = getElection();
        lockedGold = getLockedGold();
        deposit();
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
    function getManageableBalance() external view returns (uint256) {
        return lockedGold.getAccountTotalLockedGold(address(this));
    }

    function getVotingVaultManager() external view returns (address, uint256) {
        return (
            vaultManagers.voting.contractAddress,
            vaultManagers.voting.rewardSharePercentage
        );
    }

    function setVotingVaultManager(VaultManager manager) external onlyOwner {
        require(
            archive.hasVaultManager(manager.owner(), address(manager)),
            "Voting vault manager is invalid"
        );
        require(
            vaultManagers.voting.contractAddress == address(0),
            "Voting vault manager already exists"
        );

        manager.registerVault();

        vaultManagers.voting.contractAddress = address(manager);
        vaultManagers.voting.rewardSharePercentage = manager
            .rewardSharePercentage();
    }

    /**
     * @notice Removes a voting vault manager
     */
    function removeVotingVaultManager() external onlyOwner {
        require(
            vaultManagers.voting.contractAddress != address(0),
            "Voting vault manager does not exist"
        );
        require(
            votes.groups.getKeys().length == 0,
            "Group votes have not been revoked"
        );

        VaultManager(vaultManagers.voting.contractAddress).deregisterVault();

        delete vaultManagers.voting;
    }

    /**
     * @notice Distributes a voting vault manager's rewards
     * @param group A validator group with active votes placed by the voting vault manager
     * @param adjacentGroupWithLessVotes An eligible validator group, adjacent to group, with less votes
     * @param adjacentGroupWithMoreVotes An eligible validator group, adjacent to group, with more votes
     * @param accountGroupIndex Index of the group for this vault's account
     */
    function distributeVotingManagerRewards(
        address group,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) public onlyOwnerOrVotingVaultManager onlyGroupWithVotes(group) {
        uint256 vaultManagerRewards = _calculateVotingManagerRewards(group);

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

        // Store the pending withdrawal details for the manager's rewards
        vaultManagers.rewards.push(
            VaultManagerReward(
                vaultManagers.voting.contractAddress,
                pendingWithdrawalValues[pendingWithdrawalValues.length - 1],
                pendingWithdrawalTimestamps[pendingWithdrawalTimestamps.length -
                    1]
            )
        );

        // Set group's activeVotesWithoutRewards to current active votes (should be equal after reward distribution)
        votes.activeVotesWithoutRewards[group] = election
            .getActiveVotesForGroupByAccount(group, address(this));
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
    ) external onlyOwnerOrVotingVaultManager onlyGroupWithVotes(group) {
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
            votes.activeVotesWithoutRewards[group],
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
    ) external onlyVotingVaultManager {
        // Validates group eligibility, sufficient vote amount, and group voting limit
        election.vote(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes
        );

        if (votes.groups.contains(group) == true) {
            return;
        }

        votes.groups.push(group);
    }

    /**
     * @notice Activates pending votes for a validator group that this vault is currently voting for
     * @param group A validator group
     */
    function activate(address group)
        external
        onlyVotingVaultManager
        onlyGroupWithVotes(group)
    {
        // Save pending votes amount before activation attempt
        uint256 pendingVotes = election.getPendingVotesForGroupByAccount(
            group,
            address(this)
        );

        // activate validates pending vote epoch and non-zero vote amount
        election.activate(group);

        // Increment activeVotesWithoutRewards by activated pending votes instead of
        // Celo active votes in order to retain reward accrual difference
        votes.activeVotesWithoutRewards[group] =
            votes.activeVotesWithoutRewards[group] +
            pendingVotes;
    }

    /**
     * @notice Iterates over voted groups and activates pending votes that are available
     * @param group A validator group
     */
    function activateAll() external onlyVotingVaultManager {
        uint256 groups = votes.groups.keys();

        for (uint256 i = 0; i < groups.length; i += 1) {
            // Call activate with group if it has activatable pending votes
            if (
                election.hasActivatablePendingVotes(address(this), groups[i]) ==
                true
            ) {
                activate(groups[i]);
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
    ) external onlyVotingVaultManager onlyGroupWithVotes(group) {
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
    ) external onlyVotingVaultManager onlyGroupWithVotes(group) {
        _revokePending(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );
    }

    /**
     * @notice Calculates the voting vault manager's rewards for a group
     * @param group A validator group with active votes placed by the voting vault manager
     * @return Manager's reward amount
     */
    function _calculateVotingManagerRewards(address group)
        internal
        view
        returns (uint256)
    {
        // totalRewardsAccrued = activeVotes (Celo) - activeVotesWithoutRewards (local)
        // vaultManagerRewards = (totalRewardsAccrued / 100) * rewardSharePercentage
        return
            election
                .getActiveVotesForGroupByAccount(group, address(this))
                .sub(votes.activeVotesWithoutRewards[group])
                .div(100)
                .mul(vaultManagers.voting.rewardSharePercentage);
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
            _calculateVotingManagerRewards(group));

        // Communicate that the amount must be less than post-reward distribution active votes
        require(
            activeVotesAfterRewardDistribution >= amount,
            "Amount is greater than active votes remaining after manager reward distribution"
        );

        // Settles rewards owed to the vault manager and brings locally-stored
        // activeVotesWithoutRewards to parity with Celo activeVotes
        distributeVotingManagerRewards(
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

        votes.activeVotesWithoutRewards[group] = election
            .getActiveVotesForGroupByAccount(group, address(this));
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
}
