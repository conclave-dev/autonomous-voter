// contracts/Vault.sol
pragma solidity ^0.5.8;

import "./celo/common/UsingRegistry.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IArchive.sol";
import "./Strategy.sol";

contract Vault is UsingRegistry {
    IArchive private archive;
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
}
