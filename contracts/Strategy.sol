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

    function initializeStrategy(
        IArchive _archive,
        address _owner,
        address _admin,
        uint256 _sharePercentage,
        uint256 _minimumGold
    ) public payable initializer {
        Ownable.initialize(_owner);

        archive = _archive;
        proxyAdmin = _admin;
        rewardSharePercentage = _sharePercentage;
        minimumManagedGold = _minimumGold;
    }

    function setProxyAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "Invalid admin address");
        proxyAdmin = _admin;
    }

    function setRewardSharePercentage(uint256 _percentage)
        external
        onlyOwner
    {
        require(_percentage > 0, "Invalid reward share percentage");
        rewardSharePercentage = _percentage;
    }

    function setMinimumManagedGold(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Invalid cGold amount");
        minimumManagedGold = _amount;
    }

    function getRewardSharePercentage() external view returns (uint256) {
        return rewardSharePercentage;
    }

    function getMinimumManagedGold() external view returns (uint256) {
        return minimumManagedGold;
    }

    function registerVault(uint256 _strategyIndex, uint256 _amount) external {
        // Crosscheck the Archive to make sure that `msg.sender` is a valid vault instance with proper owner
        address vaultAddress = archive.getVault(Vault(msg.sender).owner());
        require(vaultAddress == msg.sender, "Invalid vault");

        require(_amount >= minimumManagedGold, "Insufficient gold");

        managedGold[vaultAddress][_strategyIndex] = _amount;
    }
}
