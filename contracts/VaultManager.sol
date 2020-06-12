// contracts/VaultManager.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./Archive.sol";
import "./Vault.sol";
import "./celo/common/libraries/AddressLinkedList.sol";

contract VaultManager is Ownable {
    using AddressLinkedList for LinkedList.List;

    Archive private archive;

    address public proxyAdmin;
    uint256 public rewardSharePercentage;
    uint256 public minimumManageableBalanceRequirement;

    LinkedList.List public vaults;

    modifier onlyVault() {
        // Confirm that Vault is in the AV network (i.e. stored within the Archive contract)
        require(
            archive.hasVault(Vault(msg.sender).owner(), msg.sender),
            "Invalid vault"
        );
        _;
    }

    function initialize(
        Archive archive_,
        address owner_,
        address admin,
        uint256 sharePercentage,
        uint256 minimumRequirement
    ) public payable initializer {
        Ownable.initialize(owner_);

        archive = archive_;
        proxyAdmin = admin;
        rewardSharePercentage = sharePercentage;
        minimumManageableBalanceRequirement = minimumRequirement;
    }

    function setProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function setRewardSharePercentage(uint256 percentage) external onlyOwner {
        require(percentage > 0, "Invalid reward share percentage");
        rewardSharePercentage = percentage;
    }

    function setMinimumManageableBalanceRequirement(uint256 amount)
        external
        onlyOwner
    {
        require(amount > 0, "Invalid cGold amount");
        minimumManageableBalanceRequirement = amount;
    }

    function hasVault(address vault) public view returns (bool) {
        return vaults.contains(vault);
    }

    function validateVault(Vault vault) internal view {
        require(!hasVault(address(vault)), "Already registered");
        require(
            vault.getManageableBalance() >= minimumManageableBalanceRequirement,
            "Does not meet minimum manageable balance requirement"
        );
    }

    function registerVault(Vault vault) external onlyVault {
        validateVault(vault);

        vaults.push(msg.sender);
    }
}
