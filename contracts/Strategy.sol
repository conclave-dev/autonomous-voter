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

    modifier onlyVault() {
        // Confirm that Vault is in the AV network (i.e. stored within the Archive contract)
        require(archive.getVault(Vault(msg.sender).owner()) == msg.sender, "Invalid vault");
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

    function registerVault(uint256 _strategyIndex, uint256 _amount) external onlyVault {
        require(_amount >= minimumManagedGold, "Amount does not meet this strategy's minimum");

        managedGold[msg.sender][_strategyIndex] = _amount;
    }
}
