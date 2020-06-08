// contracts/Archive.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "celo-monorepo/packages/protocol/contracts/common/UsingPrecompiles.sol";

import "./celo/common/UsingRegistry.sol";
import "./Vault.sol";
import "./Strategy.sol";

contract Archive is Initializable, Ownable, UsingRegistry, UsingPrecompiles {
    // Epoch are used for accurately calculating the amount of rewards accrued
    struct Epoch {
        // Result from EpochRewards's calculateTargetEpochRewards() (2nd return value)
        uint256 voterRewards;
        // Result from Election's getActiveVotes()
        uint256 activeVotes;
    }

    mapping(address => address) public vaults;
    mapping(address => address) public strategies;
    mapping(uint256 => Epoch) private epochs;

    address public vaultFactory;
    address public strategyFactory;

    event VaultFactorySet(address);
    event StrategyFactorySet(address);
    event VaultUpdated(address, address);
    event StrategyUpdated(address, address);
    event EpochSet(uint256, uint256);

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

    function setEpoch() public {
        uint256 epochNumber = getEpochNumberOfBlock(block.number);
        (, uint256 voterRewards, , ) = getEpochRewards()
            .calculateTargetEpochRewards();
        uint256 activeVotes = getElection().getActiveVotes();

        epochs[epochNumber] = Epoch(voterRewards, activeVotes);

        emit EpochSet(voterRewards, activeVotes);
    }
}
