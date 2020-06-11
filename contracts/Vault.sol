// contracts/Vault.sol
pragma solidity ^0.5.8;

import "./celo/common/UsingRegistry.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IArchive.sol";
import "./Strategy.sol";

contract Vault is UsingRegistry {
    IArchive public archive;
    address public proxyAdmin;
    uint256 public unmanagedGold;

    struct ManagedGold {
        address strategyAddress;
        uint256 amount;
        mapping(address => uint256) groupVotes;
        address[] groupAddresses;
        uint256 groupVotesActiveAtEpoch;
        uint256 rewardSharePercentage;
    }

    ManagedGold[] public managedGold;

    function initialize(
        address _registry,
        IArchive _archive,
        address owner,
        address admin
    ) public payable initializer {
        UsingRegistry.initializeRegistry(msg.sender, _registry);
        Ownable.initialize(owner);

        archive = _archive;
        proxyAdmin = admin;
        _registerAccount();
        _depositGold();
    }

    function deposit() public payable onlyOwner {
        require(msg.value > 0, "Deposited funds must be larger than 0");
        _depositGold();
    }

    function addManagedGold(address strategyAddress, uint256 amount)
        external
        onlyOwner
    {
        require(
            amount > 0 && amount <= unmanagedGold,
            "Deposited funds must be > 0 and <= unmanaged gold"
        );

        // Crosscheck the validity of the specified strategy instance
        require(
            archive.getStrategy(Strategy(strategyAddress).owner()) ==
                strategyAddress,
            "Invalid strategy specified"
        );

        IStrategy strategy = IStrategy(strategyAddress);
        uint256 rewardSharePercentage = strategy.getRewardSharePercentage();

        // Initialize a new managedGold entry
        uint256 strategyIndex = managedGold.length;

        ManagedGold memory newManagedGold;
        newManagedGold.strategyAddress = strategyAddress;
        newManagedGold.amount = amount;
        newManagedGold.groupVotesActiveAtEpoch = 0;
        newManagedGold.rewardSharePercentage = rewardSharePercentage;

        managedGold.push(newManagedGold);

        unmanagedGold -= amount;

        strategy.registerVault(strategyIndex, amount);
    }

    function setProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function _registerAccount() internal {
        require(
            getAccounts().createAccount(),
            "Failed to register vault account"
        );
    }

    function _depositGold() internal {
        // Update total unmanaged gold
        unmanagedGold += msg.value;

        // Immediately lock the deposit
        getLockedGold().lock.value(msg.value)();
    }
}
