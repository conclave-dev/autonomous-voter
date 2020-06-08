// contracts/Archive.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./Vault.sol";
import "./Strategy.sol";

contract Archive is Initializable, Ownable {
    address public vaultFactory;
    address public strategyFactory;
    mapping(address => address) public vaults;
    mapping(address => address) public strategies;

    event VaultFactorySet(address);
    event StrategyFactorySet(address);
    event VaultUpdated(address, address);
    event StrategyUpdated(address, address);

    modifier onlyVaultFactory() {
        require(msg.sender == vaultFactory, "Sender is not vault factory");
        _;
    }

    modifier onlyStrategyFactory() {
        require(msg.sender == strategyFactory, "Sender is not strategy factory");
        _;
    }

    function initialize(address _owner) public initializer {
        Ownable.initialize(_owner);
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
}
