// contracts/Vault.sol
pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./celo/common/UsingRegistry.sol";
import "./Archive.sol";
import "./VaultManager.sol";
import "./celo/common/libraries/AddressLinkedList.sol";
import "./celo/common/FixidityLib.sol";

contract Vault is UsingRegistry {
    using SafeMath for uint256;
    using AddressLinkedList for LinkedList.List;
    using FixidityLib for FixidityLib.Fraction;

    // Rewards set aside for a manager - cannot be withdrawn by the owner, unless it expires
    // TODO: Add reward withdrawal expiry logic
    struct ManagerReward {
        address recipient;
        uint256 amount;
        uint256 timestamp;
    }

    struct VotingManager {
        address contractAddress;
        // The voting vault manager's reward share percentage when they were added
        // This protects the vault owner from increases by the voting vault manager
        uint256 rewardSharePercentage;
    }

    Archive public archive;
    IElection public election;
    ILockedGold public lockedGold;

    VotingManager public votingManager;
    ManagerReward[] public votingManagerRewards;
    LinkedList.List public groupsWithActiveVotes;
    mapping(address => uint256) public groupActiveVotesWithoutRewards;

    address public proxyAdmin;

    modifier onlyVotingManager() {
        require(
            msg.sender == votingManager.contractAddress,
            "Not the voting vault manager"
        );
        _;
    }

    // This modifier is sparingly applied to voting-related methods callable by the owner
    // and the manager. Generally, we don't want the owner to influence the vault's voting
    // groups, unless it is their intent to remove the voting vault manager.
    modifier onlyOwnerOrVotingManager() {
        require(
            msg.sender == owner() ||
                msg.sender == votingManager.contractAddress,
            "Not the owner or voting vault manager"
        );
        _;
    }

    modifier onlyGroupWithVotes(address group) {
        require(
            groupsWithActiveVotes.contains(group) == true,
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
            delete groupActiveVotesWithoutRewards[group];

            groupsWithActiveVotes.remove(group);
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

    // Gets the Vault's nonvoting locked gold amount
    function getNonvotingBalance() public view returns (uint256) {
        return getLockedGold().getAccountNonvotingLockedGold(address(this));
    }

    function getVotingManager() external view returns (address, uint256) {
        return (
            votingManager.contractAddress,
            votingManager.rewardSharePercentage
        );
    }

    function setVotingManager(VaultManager manager) external onlyOwner {
        require(
            archive.hasVaultManager(manager.owner(), address(manager)),
            "Voting vault manager is invalid"
        );
        require(
            votingManager.contractAddress == address(0),
            "Voting vault manager already exists"
        );

        manager.registerVault();

        votingManager.contractAddress = address(manager);
        votingManager.rewardSharePercentage = manager.rewardSharePercentage();
    }

    /**
     * @notice Removes a voting vault manager
     */
    function removeVotingManager() external onlyOwner {
        require(
            votingManager.contractAddress != address(0),
            "Voting vault manager does not exist"
        );
        require(
            groupsWithActiveVotes.getKeys().length == 0,
            "Group votes have not been revoked"
        );

        VaultManager(votingManager.contractAddress).deregisterVault();

        delete votingManager;
    }

    /**
     * @notice Calculates the voting vault manager's rewards for a group
     * @param group A validator group with active votes placed by the voting vault manager
     * @return Manager's reward amount
     */
    function calculateVotingManagerRewards(address group)
        public
        view
        returns (uint256)
    {
        FixidityLib.Fraction memory activeVotes = FixidityLib.newFixed(
            election.getActiveVotesForGroupByAccount(group, address(this))
        );
        FixidityLib.Fraction memory activeVotesWithoutRewards = FixidityLib
            .newFixed(groupActiveVotesWithoutRewards[group]);
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
                FixidityLib.newFixed(votingManager.rewardSharePercentage)
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
    function distributeVotingManagerRewards(
        address group,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) public onlyOwnerOrVotingManager onlyGroupWithVotes(group) {
        uint256 vaultManagerRewards = calculateVotingManagerRewards(group);

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
        votingManagerRewards.push(
            ManagerReward(
                votingManager.contractAddress,
                pendingWithdrawalValues[pendingWithdrawalValues.length - 1],
                pendingWithdrawalTimestamps[pendingWithdrawalTimestamps.length -
                    1]
            )
        );

        // Set group's groupActiveVotesWithoutRewards to current active votes (should be equal after reward distribution)
        groupActiveVotesWithoutRewards[group] = election
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
    ) external onlyOwnerOrVotingManager onlyGroupWithVotes(group) {
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
            groupActiveVotesWithoutRewards[group],
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
    ) external onlyVotingManager {
        // Validates group eligibility, sufficient vote amount, and group voting limit
        election.vote(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes
        );

        if (groupsWithActiveVotes.contains(group) == true) {
            return;
        }

        groupsWithActiveVotes.push(group);
    }

    /**
     * @notice Activates pending votes for a validator group that this vault is currently voting for
     * @param group A validator group
     */
    function activate(address group)
        public
        onlyVotingManager
        onlyGroupWithVotes(group)
    {
        // Save pending votes amount before activation attempt
        uint256 pendingVotes = election.getPendingVotesForGroupByAccount(
            group,
            address(this)
        );

        // activate validates pending vote epoch and non-zero vote amount
        election.activate(group);

        // Increment groupActiveVotesWithoutRewards by activated pending votes instead of
        // Celo active votes in order to retain reward accrual difference
        groupActiveVotesWithoutRewards[group] =
            groupActiveVotesWithoutRewards[group] +
            pendingVotes;
    }

    /**
     * @notice Iterates over voted groups and activates pending votes that are available
     */
    function activateAll() external onlyVotingManager {
        address[] memory groups = groupsWithActiveVotes.getKeys();

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
    ) external onlyVotingManager onlyGroupWithVotes(group) {
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
    ) external onlyVotingManager onlyGroupWithVotes(group) {
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
            calculateVotingManagerRewards(group));

        // Communicate that the amount must be less than post-reward distribution active votes
        require(
            activeVotesAfterRewardDistribution >= amount,
            "Amount is greater than active votes remaining after manager reward distribution"
        );

        // Settles rewards owed to the vault manager and brings locally-stored
        // groupActiveVotesWithoutRewards to parity with Celo activeVotes
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

        groupActiveVotesWithoutRewards[group] = election
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
