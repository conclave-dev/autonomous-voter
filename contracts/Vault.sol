// contracts/Vault.sol
pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./celo/common/UsingRegistry.sol";
import "./Archive.sol";
import "./VaultManager.sol";
import "./celo/common/libraries/AddressLinkedList.sol";

contract Vault is UsingRegistry {
    using LinkedList for LinkedList.List;
    using SafeMath for uint256;

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
        uint256 minimumManageableBalanceRequirement;
    }

    Archive public archive;
    IElection public election;
    ILockedGold public lockedGold;

    VotingManager public votingManager;
    ManagerReward[] public votingManagerRewards;
    LinkedList.List public groupsWithActiveVotes;
    mapping(address => uint256) public groupActiveVotesWithoutRewards;
    LinkedList.List public pendingWithdrawals;

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
            groupsWithActiveVotes.contains(AddressLinkedList.toBytes(group)) ==
                true,
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

            groupsWithActiveVotes.remove(AddressLinkedList.toBytes(group));
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

    // Fallback function so the vault can accept incoming withdrawal/reward transfers
    function() external payable {}

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
        return lockedGold.getAccountNonvotingLockedGold(address(this));
    }

    function getVotingManager()
        external
        view
        returns (
            address,
            uint256,
            uint256
        )
    {
        return (
            votingManager.contractAddress,
            votingManager.rewardSharePercentage,
            votingManager.minimumManageableBalanceRequirement
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
        votingManager.minimumManageableBalanceRequirement = manager
            .minimumManageableBalanceRequirement();
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

    // Calculate the distribution of votes to be revoked in order to complete a withdrawal request
    function _purgeVotes(
        address[] memory groups,
        uint256[] memory votes,
        uint256 amount
    ) internal pure returns (uint256[] memory) {
        uint256[] memory indexes = new uint256[](groups.length);
        uint256[] memory purged = new uint256[](groups.length);

        for (uint256 i = 0; i < groups.length; i = i.add(1)) {
            indexes[i] = i;
        }

        // Use a sorted indexes so we can quickly iterate through the groups
        // and calculate the votes to be purged for each groups.
        // Otherwise it will run much slower due to lots of repeated lookups/operations
        uint256 tmpIndex;
        for (uint256 i = 0; i < groups.length - 1; i = i.add(1)) {
            for (uint256 j = i + 1; j < groups.length; j = j.add(1)) {
                if (votes[indexes[i]] > votes[indexes[j]]) {
                    tmpIndex = indexes[i];
                    indexes[i] = indexes[j];
                    indexes[j] = tmpIndex;
                }
            }
        }

        uint256 currentAmount = amount;
        uint256 divided;
        uint256 modulo;
        divided = currentAmount.div(groups.length);
        modulo = currentAmount.mod(groups.length);

        for (uint256 i = 0; i < groups.length; i = i.add(1)) {
            // If the mean/average is higher than the votes for this group,
            // purge all its votes, then recalculate the mean distribution as well remainder for the remaining groups.
            // Else, purge evenly across the groups, and add extra 1 purged vote for the top groups for the remainder
            if (votes[indexes[i]] < divided) {
                purged[indexes[i]] = votes[indexes[i]];

                currentAmount = currentAmount.sub(votes[indexes[i]]);

                if (i < groups.length.sub(1)) {
                    divided = currentAmount.div(groups.length.sub(i).sub(1));
                    modulo = currentAmount.mod(groups.length.sub(i).sub(1));
                }
            } else if (i >= groups.length - modulo) {
                purged[indexes[i]] = divided.add(1);
            } else {
                purged[indexes[i]] = divided;
            }
        }

        return purged;
    }

    // Find adjacent groups with less and more votes than the specified one after the updated vote count
    function _findLesserAndGreater(
        address group,
        uint256 vote,
        bool isRevoke
    ) internal view returns (address, address) {
        address[] memory groups;
        uint256[] memory votes;
        (groups, votes) = election.getTotalVotesForEligibleValidatorGroups();
        address lesser = address(0);
        address greater = address(0);

        // Get the current totalVote count for the specified group
        uint256 totalVote = election.getTotalVotesForGroupByAccount(
            group,
            address(this)
        );
        if (isRevoke) {
            totalVote = totalVote.sub(vote);
        } else {
            totalVote = totalVote.add(vote);
        }

        // Look for the adjacent groups with less and more votes, respectively
        for (uint256 i = 0; i < groups.length; i = i.add(1)) {
            if (groups[i] != group) {
                if (votes[i] <= totalVote) {
                    lesser = groups[i];
                    break;
                }
                greater = groups[i];
            }
        }

        return (lesser, greater);
    }

    function initiateWithdrawal(uint256 amount) external onlyOwner {
        // Populate the data used to check the steps required in order to be able to withdraw the specified amount
        address[] memory groups = _getGroupsWithActiveVotes();
        uint256[] memory activeVotes = new uint256[](groups.length);
        uint256[] memory pendingVotes = new uint256[](groups.length);
        uint256 nonVotingBalance = getNonvotingBalance();
        uint256 totalPending = 0;
        uint256 totalAvailableVotes = nonVotingBalance;

        for (uint256 i = 0; i < groups.length; i = i.add(1)) {
            activeVotes[i] = election
                .getActiveVotesForGroupByAccount(groups[i], address(this))
                .sub(calculateVotingManagerRewards(groups[i]));
            pendingVotes[i] = election.getPendingVotesForGroupByAccount(
                groups[i],
                address(this)
            );
            totalPending = totalPending.add(pendingVotes[i]);
            totalAvailableVotes = totalAvailableVotes.add(activeVotes[i]).add(
                pendingVotes[i]
            );
        }

        // Check if the withdrawal amount specified is within the limit (after considering manager rewards, etc)
        totalAvailableVotes = totalAvailableVotes.sub(
            votingManager.minimumManageableBalanceRequirement
        );

        require(
            amount > 0 && amount <= totalAvailableVotes,
            "Invalid amount specified"
        );

        // Calculate how many extra votes need to be revoked to make up for the remaining amount
        uint256 remainingAmount = amount;
        if (remainingAmount > nonVotingBalance) {
            remainingAmount = remainingAmount.sub(nonVotingBalance);
        } else {
            remainingAmount = 0;
        }

        // If the non voting balance doesn't cover the specified amount, attempt to revoke any available pending votes first
        if (remainingAmount > 0 && totalPending > 0) {
            remainingAmount = remainingAmount.sub(nonVotingBalance);
            uint256[] memory purgedVotes = _purgeVotes(
                groups,
                pendingVotes,
                remainingAmount
            );
            for (uint256 i = 0; i < groups.length; i = i.add(1)) {
                address lesser;
                address greater;
                (lesser, greater) = _findLesserAndGreater(
                    groups[i],
                    purgedVotes[i],
                    true
                );

                if (purgedVotes[i] > 0) {
                    remainingAmount = remainingAmount.sub(purgedVotes[i]);

                    _revokePending(
                        groups[i],
                        purgedVotes[i],
                        lesser,
                        greater,
                        i
                    );
                }
            }
        }

        // If the non voting balance still doesn't cover the specified amount, proceed to revoke active votes
        if (remainingAmount > 0) {
            uint256[] memory purgedVotes = _purgeVotes(
                groups,
                activeVotes,
                remainingAmount
            );
            for (uint256 i = 0; i < groups.length; i = i.add(1)) {
                address lesser;
                address greater;

                if (purgedVotes[i] > 0) {
                    (lesser, greater) = _findLesserAndGreater(
                        groups[i],
                        purgedVotes[i],
                        true
                    );

                    _revokeActive(
                        groups[i],
                        purgedVotes[i],
                        lesser,
                        greater,
                        i
                    );
                }
            }
        }

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

    function withdraw() external onlyOwner {
        (uint256[] memory amounts, uint256[] memory timestamps) = lockedGold
            .getPendingWithdrawals(address(this));

        // Iterate through the withdrawal lists.
        // Note that we need to fully iterate it since withdrawal with further timestamp can be located in front
        // as they're not always sorted due to shifting on records deletion
        uint256 totalWithdrawalAmount = 0;
        for (uint256 i = 0; i < timestamps.length; i = i.add(1)) {
            require(timestamps[i] < now, "Withdrawal is not yet available");
            // Crosscheck with our local records
            bytes32 encodedWithdrawal = keccak256(
                abi.encode(owner(), amounts[i], timestamps[i])
            );
            if (pendingWithdrawals.contains(encodedWithdrawal) == true) {
                totalWithdrawalAmount = totalWithdrawalAmount.add(amounts[i]);
                lockedGold.withdraw(i);
            }
        }

        // Forward the withdrawn funds to the vault owner
        msg.sender.transfer(totalWithdrawalAmount);
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

        if (
            groupsWithActiveVotes.contains(AddressLinkedList.toBytes(group)) ==
            true
        ) {
            return;
        }

        groupsWithActiveVotes.push(AddressLinkedList.toBytes(group));
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
        address[] memory groups = _getGroupsWithActiveVotes();

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
        // totalRewardsAccrued = activeVotes (Celo) - groupActiveVotesWithoutRewards (local)
        // vaultManagerRewards = (totalRewardsAccrued / 100) * rewardSharePercentage
        return
            election
                .getActiveVotesForGroupByAccount(group, address(this))
                .sub(groupActiveVotesWithoutRewards[group])
                .div(100)
                .mul(votingManager.rewardSharePercentage);
    }

    // Wrapper to conveniently get the addresses of groups with active votes by this vault
    function _getGroupsWithActiveVotes()
        internal
        view
        returns (address[] memory)
    {
        bytes32[] memory groups = groupsWithActiveVotes.getKeys();
        address[] memory groupAddresses = new address[](groups.length);

        for (uint256 i = 0; i < groups.length; i = i.add(1)) {
            groupAddresses[i] = AddressLinkedList.toAddress(groups[i]);
        }

        return groupAddresses;
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
