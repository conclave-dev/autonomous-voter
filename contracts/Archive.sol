// contracts/Archive.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "celo-monorepo/packages/protocol/contracts/common/UsingPrecompiles.sol";

import "./celo/common/UsingRegistry.sol";
import "./Vault.sol";
import "./Strategy.sol";

contract Archive is Initializable, Ownable, UsingRegistry, UsingPrecompiles {
    using SafeMath for uint256;

    // EpochRewards data is used to calculate an election group's voter rewards
    struct EpochRewards {
        // Result from EpochRewards's calculateTargetEpochRewards() (2nd return value)
        uint256 voterRewards;
        // Result from Election's getActiveVotes()
        uint256 activeVotes;
    }

    mapping(address => address) public vaults;
    mapping(address => address) public strategies;
    mapping(uint256 => EpochRewards) private epochRewards;

    address public vaultFactory;
    address public strategyFactory;

    event VaultFactorySet(address);
    event StrategyFactorySet(address);
    event VaultUpdated(address, address);
    event StrategyUpdated(address, address);
    event EpochRewardsSet(uint256, uint256, uint256);

    modifier onlyVaultFactory() {
        require(msg.sender == vaultFactory, "Sender is not vault factory");
        _;
    }

    modifier onlyStrategyFactory() {
        require(
            msg.sender == strategyFactory,
            "Sender is not strategy factory"
        );
        _;
    }

    function initialize(address registry) public initializer {
        Ownable.initialize(msg.sender);
        initializeRegistry(msg.sender, registry);
    }

    function setVaultFactory(address _vaultFactory) public onlyOwner {
        vaultFactory = _vaultFactory;

        emit VaultFactorySet(vaultFactory);
    }

    function setStrategyFactory(address _strategyFactory) public onlyOwner {
        strategyFactory = _strategyFactory;

        emit StrategyFactorySet(strategyFactory);
    }

    function _isVaultOwner(address vault, address account) internal view {
        require(
            Vault(vault).owner() == account,
            "Account is not the vault owner"
        );
    }

    function _isStrategyOwner(address strategy, address account) internal view {
        require(
            Strategy(strategy).owner() == account,
            "Account is not the strategy owner"
        );
    }

    function getVault(address owner) external view returns (address) {
        return vaults[owner];
    }

    function getStrategy(address owner) external view returns (address) {
        return strategies[owner];
    }

    function updateVault(address vault, address account)
        public
        onlyVaultFactory
    {
        _isVaultOwner(vault, account);

        vaults[account] = vault;

        emit VaultUpdated(msg.sender, vault);
    }

    function updateStrategy(address strategy, address account)
        public
        onlyStrategyFactory
    {
        _isStrategyOwner(strategy, account);

        strategies[account] = strategy;

        emit StrategyUpdated(msg.sender, strategy);
    }

    function hasEpochRewards(uint256 epochNumber) internal view returns (bool) {
        // Only checking activeVotes since there wouldn't be voter rewards if it were 0
        return epochRewards[epochNumber].activeVotes > 0;
    }

    function setEpochRewards(
        uint256 epochNumber,
        uint256 activeVotes,
        uint256 voterRewards
    ) internal returns (EpochRewards storage) {
        require(
            epochNumber <= getEpochNumberOfBlock(block.number),
            "Invalid epochNumber"
        );

        epochRewards[epochNumber] = EpochRewards(activeVotes, voterRewards);

        emit EpochRewardsSet(epochNumber, activeVotes, voterRewards);

        return epochRewards[epochNumber];
    }

    function getEpochRewards(uint256 epochNumber)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (
            epochNumber,
            epochRewards[epochNumber].activeVotes,
            epochRewards[epochNumber].voterRewards
        );
    }

    function setCurrentEpochRewards()
        public
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 epochNumber = getEpochNumberOfBlock(block.number);
        EpochRewards storage currentEpochRewards = epochRewards[epochNumber];

        if (hasEpochRewards(epochNumber)) {
            return getEpochRewards(epochNumber);
        }

        // Retrieve epoch rewards data from protocol contracts
        uint256 activeVotes = getElection().getActiveVotes();
        (, uint256 voterRewards, , ) = getEpochRewards()
            .calculateTargetEpochRewards();

        setEpochRewards(epochNumber, activeVotes, voterRewards);

        return (
            epochNumber,
            currentEpochRewards.activeVotes,
            currentEpochRewards.voterRewards
        );
    }
}
