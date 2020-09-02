// contracts/Archive.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";

import "./celo/common/UsingRegistry.sol";
import "./celo/common/libraries/UsingPrecompiles.sol";
import "./archive-modules/ElectionDataProvider.sol";
import "./celo/common/libraries/AddressLinkedList.sol";
import "./Vault.sol";

contract Archive is
    Initializable,
    Ownable,
    UsingRegistry,
    UsingPrecompiles,
    ElectionDataProvider
{
    using AddressLinkedList for LinkedList.List;

    // Factory contracts that are able to modify the lists below
    address public vaultFactory;

    // Vaults mapped by their owner's address
    mapping(address => LinkedList.List) public vaults;

    modifier onlyVaultFactory() {
        require(msg.sender == vaultFactory, "Sender is not the vault factory");
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

        ElectionDataProvider.initialize(getElection());
    }

    function setVaultFactory(address vaultFactory_) external onlyOwner {
        vaultFactory = vaultFactory_;
    }

    function getVaultsByOwner(address owner_)
        external
        view
        returns (address[] memory)
    {
        return vaults[owner_].getKeys();
    }

    function hasVault(address owner_, address vault)
        external
        view
        returns (bool)
    {
        return vaults[owner_].contains(vault);
    }

    function associateVaultWithOwner(address vault, address owner_)
        external
        onlyVaultFactory
    {
        require(!vaults[owner_].contains(vault), "Vault has already been set");
        vaults[owner_].push(vault);
    }
}
