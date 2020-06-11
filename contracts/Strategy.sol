// contracts/Strategy.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./interfaces/IArchive.sol";
import "./Vault.sol";
import "./celo/common/libraries/AddressLinkedList.sol";

contract Strategy is Ownable {
    using AddressLinkedList for LinkedList.List;

    IArchive private archive;

    address public proxyAdmin;
    uint256 public rewardSharePercentage;
    uint256 public minimumManageableBalanceRequirement;

    LinkedList.List public vaults;

    modifier onlyVault() {
        // Confirm that Vault is in the AV network (i.e. stored within the Archive contract)
        require(
            archive.getVault(Vault(msg.sender).owner()) == msg.sender,
            "Invalid vault"
        );
        _;
    }

    function initialize(
        IArchive _archive,
        address owner,
        address admin,
        uint256 sharePercentage,
        uint256 minimumGold
    ) public payable initializer {
        Ownable.initialize(owner);

        archive = _archive;
        proxyAdmin = _admin;
        rewardSharePercentage = _sharePercentage;
        minimumManageableBalanceRequirement = _minimumGold;
    }

    function setProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function setRewardSharePercentage(uint256 percentage) external onlyOwner {
        require(percentage > 0, "Invalid reward share percentage");
        rewardSharePercentage = percentage;
    }

    function setMinimumManageableBalanceRequirement(uint256 _amount)
        external
        onlyOwner
    {
        require(_amount > 0, "Invalid cGold amount");
        minimumManageableBalanceRequirement = _amount;
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
