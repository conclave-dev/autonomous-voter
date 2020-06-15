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

    modifier onlyOwnerOrVotingVaultManager() {
        require(
            msg.sender == owner() ||
                msg.sender == vaultManagers.voting.contractAddress,
            "Not the owner or voting vault manager"
        );
        _;
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

    function mustBeVotingForGroup(address group) internal view {
        require(votes.groups.contains(group) == true, "Group does not exist");
    }

    /**
     * @notice Calculates and distributes a voting vault manager's rewards
     * @param group A validator group with active votes placed by the voting vault manager
     * @param adjacentGroupWithLessVotes An eligible validator group, adjacent to group, with less votes
     * @param adjacentGroupWithMoreVotes An eligible validator group, adjacent to group, with more votes
     * @param accountGroupIndex Index of the group for the vault's account
     * @return Manager's reward amount
     */
    function distributeVotingVaultManagerRewards(
        address group,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) public onlyOwnerOrVotingVaultManager returns (uint256) {
        mustBeVotingForGroup(group);

        uint256 activeVotes = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );

        require(activeVotes > 0, "Group does not have active votes");

        // Total group rewards = current active votes - active votes without rewards
        // Vault manager's rewards = total group rewards percentage point * reward share percentage (#1-100)
        uint256 vaultManagerRewards = activeVotes
            .sub(votes.activeVotesWithoutRewards[group])
            .div(100)
            .mul(vaultManagers.voting.rewardSharePercentage);

        require(
            vaultManagerRewards > 0,
            "Group does not have rewards to distribute"
        );

        // Revoke active votes equal to the manager's rewards, so that they can be unlocked and withdrawn
        election.revokeActive(
            group,
            vaultManagerRewards,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );

        // Unlock tokens equal to the manager's rewards
        lockedGold.unlock(vaultManagerRewards);

        // Retrieve the Vault's pending withdrawals (manager's rewards will be the last element)
        (uint256[] memory values, uint256[] memory timestamps) = lockedGold
            .getPendingWithdrawals(address(this));

        // Store the pending withdrawal details
        vaultManagers.rewards.push(
            VaultManagerReward(
                vaultManagers.voting.contractAddress,
                values[values.length - 1],
                timestamps[timestamps.length - 1]
            )
        );

        // Bring activeVotesWithoutRewards to parity with group's active votes
        votes.activeVotesWithoutRewards[group] = activeVotes.sub(
            vaultManagerRewards
        );

        // Safety-check, just to be sure
        require(
            votes.activeVotesWithoutRewards[group] ==
                election.getActiveVotesForGroupByAccount(group, address(this)),
            "Vault active votes does not equal election active votes"
        );

        return vaultManagerRewards;
    }

    /**
     * @notice Revokes a group's votes and removes them from state
     * @param group Groups with votes (must maintain the same order as that of the vault account)
     * @param adjacentGroupWithLessVotes List of adjacent eligible validator groups with less votes
     * @param adjacentGroupWithMoreVotes List of adjacent eligible validator groups with more votes
     * @param accountGroupIndex Index of the group for the vault's account
     */
    function revokeAll(
        address group,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) external onlyOwnerOrVotingVaultManager {
        mustBeVotingForGroup(group);

        // If there are active votes for this group, revoke them and update storage
        if (votes.activeVotesWithoutRewards[group] > 0) {
            // Distributes the rewards that were earned by the voting vault manager
            distributeVotingVaultManagerRewards(
                group,
                adjacentGroupWithLessVotes,
                adjacentGroupWithMoreVotes,
                accountGroupIndex
            );

            // Revoke active votes for this group, if any
            election.revokeAllActive(
                group,
                adjacentGroupWithLessVotes,
                adjacentGroupWithMoreVotes,
                accountGroupIndex
            );

            delete votes.activeVotesWithoutRewards[group];
        }

        uint256 pendingVotes = election.getPendingVotesForGroupByAccount(
            group,
            address(this)
        );

        // If there are pending votes for this group, revoke them
        if (pendingVotes > 0) {
            election.revokePending(
                group,
                pendingVotes,
                adjacentGroupWithLessVotes,
                adjacentGroupWithMoreVotes,
                accountGroupIndex
            );
        }

        votes.groups.remove(group);
    }

    function vote(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes
    ) external onlyVotingVaultManager {
        // Lean on Election's vote validation for group eligibility, non-zero vote amount, and
        // adherance to the group voting limit
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

    function activateVotes(address group) external onlyVotingVaultManager {
        mustBeVotingForGroup(group);

        // Save pending votes amount before activation attempt
        uint256 pendingVotes = election.getPendingVotesForGroupByAccount(
            group,
            address(this)
        );

        // activate validates pending vote epoch and non-zero vote amount
        election.activate(group);

        // Increment activeVotesWithoutRewards by activated pending votes
        votes.activeVotesWithoutRewards[group] =
            votes.activeVotesWithoutRewards[group] +
            pendingVotes;
    }
}
