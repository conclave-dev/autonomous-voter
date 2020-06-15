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
        // TODO: Add reward withdrawal expiry logic
    }

    // Rewards set aside for a manager - cannot be withdrawn by the owner, unless it expires
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
        // Pending withdrawal indexes associated with a voting vault manager's rewards
        uint256[] pendingRewardIndexes;
    }

    struct Votes {
        mapping(address => uint256) activeVotes;
        LinkedList.List groups;
    }

    Archive private archive;
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
        deposit();
    }

    function setProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than zero");

        // Immediately lock the deposit
        getLockedGold().lock.value(msg.value)();
    }

    // Gets the Vault's locked gold amount (both voting and nonvoting)
    function getManageableBalance() public view returns (uint256) {
        return getLockedGold().getAccountTotalLockedGold(address(this));
    }

    // Gets the Vault's nonvoting locked gold amount
    function getNonvotingBalance() public view returns (uint256) {
        return getLockedGold().getAccountNonvotingLockedGold(address(this));
    }

    function verifyVaultManager(VaultManager manager) internal view {
        require(
            archive.hasVaultManager(manager.owner(), address(manager)),
            "Voting manager is invalid"
        );
    }

    function setVotingVaultManager(VaultManager manager) external onlyOwner {
        verifyVaultManager(manager);

        vaultManagers.voting.contractAddress = address(manager);
        vaultManagers.voting.rewardSharePercentage = manager
            .rewardSharePercentage();

        manager.registerVault(this);
    }

    function getVotingVaultManager() public view returns (address, uint256) {
        return (
            vaultManagers.voting.contractAddress,
            vaultManagers.voting.rewardSharePercentage
        );
    }

    function removeVotingVaultManager() external onlyOwner {
        // TODO: Update to distribute voting vault manager rewards first
        delete vaultManagers.voting;
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
    ) public returns (uint256) {
        IElection election = getElection();
        uint256 activeVotes = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );

        require(activeVotes > 0, "Group does not have active votes");

        // Total group rewards = current active votes - active votes at last reward distribution
        // Vault manager rewards = total group rewards percentage point * reward share percentage (#1-100)
        uint256 vaultManagerRewards = activeVotes
            .sub(votes.activeVotes[group])
            .div(100)
            .mul(vaultManagers.voting.rewardSharePercentage);

        require(vaultManagerRewards > 0, "Group does not have rewards to distribute");

        // Revoke active votes equal to the manager's rewards, so that they can be unlocked and withdrawn
        election.revokeActive(
            group,
            vaultManagerRewards,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );

        ILockedGold lockedGold = getLockedGold();

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

        // Update the group's votes (current active votes - manager rewards)
        votes.activeVotes[group] = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );

        return vaultManagerRewards;
    }
}
