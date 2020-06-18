// contracts/Archive.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "celo-monorepo/packages/protocol/contracts/common/UsingPrecompiles.sol";

import "./celo/common/UsingRegistry.sol";
import "./Vault.sol";
import "./VaultManager.sol";

contract Archive is Initializable, Ownable, UsingRegistry, UsingPrecompiles {
    using AddressLinkedList for LinkedList.List;

    // Factory contracts that are able to modify the lists below
    address public vaultFactory;
    address public vaultManagerFactory;

    // Vaults and vault managers mapped by their owner's address
    mapping(address => LinkedList.List) public vaults;
    mapping(address => LinkedList.List) public vaultManagers;

    modifier onlyVaultFactory() {
        require(msg.sender == vaultFactory, "Sender is not vault factory");
        _;
    }

    modifier onlyVaultManagerFactory() {
        require(
            msg.sender == vaultManagerFactory,
            "Not the vault manager factory"
        );
        _;
    }

    function initialize(address registry_) public initializer {
        Ownable.initialize(msg.sender);

        // registry_ has a trailing underscore to avoid collision with inherited prop from UsingRegistry
        initializeRegistry(msg.sender, registry_);
    }

    function setVaultFactory(address vaultFactory_) public onlyOwner {
        vaultFactory = vaultFactory_;
    }

    function setVaultManagerFactory(address vaultManagerFactory_)
        public
        onlyOwner
    {
        vaultManagerFactory = vaultManagerFactory_;
    }

    function _isVaultOwner(address vault, address owner_) internal view {
        require(
            Vault(vault).owner() == owner_,
            "Account is not the vault owner"
        );
    }

    function _isVaultManagerOwner(address vaultManager, address owner_)
        internal
        view
    {
        require(
            VaultManager(vaultManager).owner() == owner_,
            "Account is not the vaultManager owner"
        );
    }

    function getVaultsByOwner(address owner_)
        external
        view
        returns (address[] memory)
    {
        return vaults[owner_].getKeys();
    }

    function getVaultManagersByOwner(address owner_)
        external
        view
        returns (address[] memory)
    {
        return vaultManagers[owner_].getKeys();
    }

    function hasVault(address owner_, address vault)
        external
        view
        returns (bool)
    {
        return vaults[owner_].contains(vault);
    }

    function hasVaultManager(address owner_, address vaultManager)
        external
        view
        returns (bool)
    {
        return vaultManagers[owner_].contains(vaultManager);
    }

    function associateVaultWithOwner(address vault, address owner_)
        public
        onlyVaultFactory
    {
        require(!vaults[owner_].contains(vault), "Vault has already been set");
        vaults[owner_].push(vault);
    }

    function associateVaultManagerWithOwner(
        address vaultManager,
        address owner_
    ) public onlyVaultManagerFactory {
        require(
            !vaultManagers[owner_].contains(vaultManager),
            "VaultManager has already been set"
        );
        vaultManagers[owner_].push(vaultManager);
    }
}
