// contracts/Vault.sol
pragma solidity ^0.5.8;

import "./celo/common/UsingRegistry.sol";
import "./Archive.sol";
import "./VaultManager.sol";

contract Vault is UsingRegistry {
    Archive private archive;
    address public proxyAdmin;

    struct VaultManagers {
        VotingVaultManager voting;
    }

    struct VotingVaultManager {
        address contractAddress;
        uint256 rewardSharePercentage;
    }

    VaultManagers private vaultManagers;

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
        delete vaultManagers.voting;
    }

    function setProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }
}
