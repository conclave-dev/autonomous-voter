// contracts/Archive.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";

import "./celo/common/UsingRegistry.sol";
import "./celo/common/libraries/UsingPrecompiles.sol";
import "./celo/common/libraries/AddressLinkedList.sol";
import "./Vault.sol";
import "./Manager.sol";

contract Archive is Initializable, Ownable, UsingRegistry, UsingPrecompiles {
    using AddressLinkedList for LinkedList.List;

    // Factory contracts that are able to modify the lists below
    address public vaultFactory;
    address public managerFactory;

    // Vaults and Managers mapped by their owner's address
    mapping(address => LinkedList.List) public vaults;
    mapping(address => LinkedList.List) public managers;

    // Tracks the list of managed vaults for each manager
    mapping(address => LinkedList.List) public managedVaults;

    modifier onlyVaultFactory() {
        require(msg.sender == vaultFactory, "Sender is not the vault factory");
        _;
    }

    modifier onlyManagerFactory() {
        require(
            msg.sender == managerFactory,
            "Sender is not the manager factory"
        );
        _;
    }

    modifier onlyVault() {
        // Confirm that Vault is in the AV network and tracked by the Archive
        require(
            vaults[Vault(msg.sender).owner()].contains(msg.sender),
            "Invalid vault"
        );
        _;
    }

    function initialize(address registry_) public initializer {
        Ownable.initialize(msg.sender);

        // registry_ has a trailing underscore to avoid collision with inherited prop from UsingRegistry
        initializeRegistry(msg.sender, registry_);
    }

    function setVaultFactory(address vaultFactory_) external onlyOwner {
        vaultFactory = vaultFactory_;
    }

    function setManagerFactory(address managerFactory_) external onlyOwner {
        managerFactory = managerFactory_;
    }

    function getVaultsByOwner(address owner_)
        external
        view
        returns (address[] memory)
    {
        return vaults[owner_].getKeys();
    }

    function getManagersByOwner(address owner_)
        external
        view
        returns (address[] memory)
    {
        return managers[owner_].getKeys();
    }

    function getManagedVaultsByManager(address manager)
        external
        view
        returns (address[] memory)
    {
        return managedVaults[manager].getKeys();
    }

    function hasVault(address owner_, address vault)
        external
        view
        returns (bool)
    {
        return vaults[owner_].contains(vault);
    }

    function hasManager(address owner_, address manager)
        external
        view
        returns (bool)
    {
        return managers[owner_].contains(manager);
    }

    function associateVaultWithOwner(address vault, address owner_)
        external
        onlyVaultFactory
    {
        require(!vaults[owner_].contains(vault), "Vault has already been set");
        vaults[owner_].push(vault);
    }

    function associateManagerWithOwner(address manager, address owner_)
        external
        onlyManagerFactory
    {
        require(
            !managers[owner_].contains(manager),
            "Manager has already been set"
        );
        managers[owner_].push(manager);
    }

    // Shared internal function to check if the specified vault is managed by the specified manager
    function _isManagedVault(address vault, address manager)
        internal
        view
        returns (bool)
    {
        return managedVaults[manager].contains(vault);
    }

    function associateVaultWithManager(address manager) external onlyVault {
        require(
            _isManagedVault(msg.sender, manager) == false,
            "Already registered"
        );

        (uint256 votingBalance, uint256 nonvotingBalance) = Vault(msg.sender)
            .getBalances();

        require(
            votingBalance.add(nonvotingBalance) >=
                Manager(manager).minimumBalanceRequirement(),
            "Insufficient manageble balance"
        );

        managedVaults[manager].push(msg.sender);
    }

    function dissociateVaultFromManager(address manager) external onlyVault {
        require(_isManagedVault(msg.sender, manager) == true, "Not registered");

        managedVaults[manager].remove(msg.sender);
    }

    function isManagedVault(address vault, address manager)
        external
        view
        returns (bool)
    {
        return _isManagedVault(vault, manager);
    }
}
