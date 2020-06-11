// contracts/Strategy.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./interfaces/IArchive.sol";
import "./Vault.sol";

contract Strategy is Ownable {
    IArchive public archive;
    address public proxyAdmin;

    uint256 public rewardSharePercentage;
    uint256 public minimumManagedGold;
    mapping(address => mapping(uint256 => uint256)) public managedGold;

    function initialize(
        IArchive _archive,
        address owner,
        address admin,
        uint256 sharePercentage,
        uint256 minimumGold
    ) public payable initializer {
        Ownable.initialize(owner);

        archive = _archive;
        proxyAdmin = admin;
        rewardSharePercentage = sharePercentage;
        minimumManagedGold = minimumGold;
    }

    function setProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function setRewardSharePercentage(uint256 percentage) external onlyOwner {
        require(percentage > 0, "Invalid reward share percentage");
        rewardSharePercentage = percentage;
    }

    function setMinimumManagedGold(uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid cGold amount");
        minimumManagedGold = amount;
    }

    function getRewardSharePercentage() external view returns (uint256) {
        return rewardSharePercentage;
    }

    function getMinimumManagedGold() external view returns (uint256) {
        return minimumManagedGold;
    }

    function registerVault(uint256 strategyIndex, uint256 amount) external {
        // Crosscheck the Archive to make sure that `msg.sender` is a valid vault instance with proper owner
        address vaultAddress = archive.getVault(Vault(msg.sender).owner());
        require(vaultAddress == msg.sender, "Invalid vault");

        require(amount >= minimumManagedGold, "Insufficient gold");

        managedGold[vaultAddress][strategyIndex] = amount;
    }
}
