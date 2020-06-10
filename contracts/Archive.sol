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

    function initialize(address _owner) public initializer {
        Ownable.initialize(_owner);
    }

    function setVaultFactory(address _vaultFactory) public onlyOwner {
        vaultFactory = _vaultFactory;
    }

    function setStrategyFactory(address _strategyFactory) public onlyOwner {
        strategyFactory = _strategyFactory;
    }

    function _isVaultOwner(address _vault, address _account) internal view {
        require(
            Vault(_vault).owner() == _account,
            "Account is not the vault owner"
        );
    }

    function _isStrategyOwner(address _strategy, address _account)
        internal
        view
    {
        require(
            Strategy(_strategy).owner() == _account,
            "Account is not the strategy owner"
        );
    }

    function getVault(address _owner) external view returns (address) {
        return vaults[_owner];
    }

    function getStrategy(address _owner) external view returns (address) {
        return strategies[_owner];
    }

    function setVault(address _vault, address _account)
        public
        onlyVaultFactory
    {
        _isVaultOwner(_vault, _account);

        vaults[_account] = _vault;
    }

    function setStrategy(address _strategy, address _account)
        public
        onlyStrategyFactory
    {
        _isStrategyOwner(_strategy, _account);

        strategies[_account] = _strategy;
    }
}
