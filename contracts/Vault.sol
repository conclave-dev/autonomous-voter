// contracts/Vault.sol
pragma solidity ^0.5.8;

import "./celo/common/UsingRegistry.sol";
import "./Archive.sol";
import "./VaultManager.sol";

contract Vault is UsingRegistry {
    using SafeMath for uint256;

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

    Archive private archive;
    VaultManagers private vaultManagers;

    address public proxyAdmin;
    mapping(address => uint256) public votes;

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

    function distributeVotingVaultManagerRewards(
        address group,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 vaultGroupIndex
    ) public {
        IElection election = getElection();
        uint256 activeGroupVotes = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );

        require(activeGroupVotes > 0, "Group does not have active votes");

        uint256 vaultManagerRewards = activeGroupVotes.sub(votes[group]).div(100).mul(
            vaultManagers.voting.rewardSharePercentage
        );

        // Revoke group votes equal to vault manager rewards
        require(
            election.revokeActive(
                group,
                vaultManagerRewards,
                adjacentGroupWithLessVotes,
                adjacentGroupWithMoreVotes,
                vaultGroupIndex
            ),
            "Unable to distribute voting vault manager rewards"
        );

        ILockedGold lockedGold = getLockedGold();

        // Unlock tokens equal to rewards (adds it to the Vault's account's pendingWithdrawals)
        lockedGold.unlock(vaultManagerRewards);

        // Retrieve the Vault's pending withdrawals (manager's rewards will be the last element)
        (uint256[] memory values, uint256[] memory timestamps) = lockedGold
            .getPendingWithdrawals(address(this));

        // Store the pending withdrawal details for the manager's rewards
        vaultManagers.rewards.push(
            VaultManagerReward(
                vaultManagers.voting.contractAddress,
                values[values.length - 1],
                timestamps[timestamps.length - 1]
            )
        );

        // Update the group's votes, which should be active votes minus rewards
        votes[group] = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );
    }
}
