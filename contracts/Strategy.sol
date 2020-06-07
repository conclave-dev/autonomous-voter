// contracts/Strategy.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./interfaces/IArchive.sol";


contract Strategy is Ownable {
    IArchive public archive;
    address public proxyAdmin;

    uint256 public rewardSharePercentage;
    uint256 public minimumManagedGold;
    mapping(address => mapping(uint256 => uint256)) managedGold;

    event VaultRegistered(address, uint256, uint256);

    function initialize(address _owner, IArchive _archive) public initializer {
        Ownable.initialize(_owner);
        archive = _archive;
    }

    function updateProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function updateRewardSharePercentage(uint256 percentage)
        external
        onlyOwner
    {
        require(percentage > 0, "Invalid percentage");
        rewardSharePercentage = percentage;
    }

    function updateMinimumManagedGold(uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid percentage");
        minimumManagedGold = amount;
    }

    function registerVault(
        address vaultOwner,
        uint256 strategyIndex,
        uint256 amount
    ) external {
        // Crosscheck the Archive to make sure that `msg.sender` is a valid vault instance with proper owner
        address vaultAddress = archive.getVault(vaultOwner);
        require(vaultAddress != msg.sender, "Invalid vault");

        emit VaultRegistered(vaultAddress, strategyIndex, amount);
    }
}
