// contracts/VaultManager.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./Archive.sol";
import "./Vault.sol";
import "./celo/common/libraries/AddressLinkedList.sol";

contract VaultManager is Ownable {
    using AddressLinkedList for LinkedList.List;

    Archive public archive;

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

    modifier onlyManagedVault(address vault) {
        require(vaults.contains(vault) == true, "Unmanaged vault");
        _;
    }

    function initialize(
        Archive archive_,
        address owner_,
        address admin,
        uint256 sharePercentage,
        uint256 minimumRequirement
    ) public initializer {
        Ownable.initialize(owner_);
        _setRewardSharePercentage(sharePercentage);

        archive = archive_;
        proxyAdmin = admin;
        minimumManageableBalanceRequirement = minimumRequirement;
    }

    function setProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function setRewardSharePercentage(uint256 percentage) public onlyOwner {
        require(
            percentage >= 1 && percentage <= 100,
            "Invalid reward share percentage"
        );
        _setRewardSharePercentage(percentage);
    }

    function _setRewardSharePercentage(uint256 percentage) internal {
        rewardSharePercentage = percentage;
    }

    function setMinimumManageableBalanceRequirement(uint256 amount)
        external
        onlyOwner
    {
        require(amount > 0, "Invalid cGold amount");
        minimumManageableBalanceRequirement = amount;
    }

    function getVaults() external view returns (address[] memory) {
        return vaults.getKeys();
    }

    function registerVault() external onlyVault {
        require(vaults.contains(msg.sender) == false, "Already registered");
        require(
            Vault(msg.sender).getManageableBalance() >=
                minimumManageableBalanceRequirement,
            "Does not meet minimum manageable balance requirement"
        );

        vaults.push(msg.sender);
    }

    function deregisterVault() external onlyVault {
        require(vaults.contains(msg.sender) == true, "Not registered");

        vaults.remove(msg.sender);
    }
}
