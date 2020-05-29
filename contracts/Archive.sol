// contracts/Archive.sol
pragma solidity ^0.5.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./Vault.sol";


contract Archive is Initializable, Ownable {
    address public vaultFactory;
    mapping(address => address) public vaults;

    event VaultFactorySet(address);
    event VaultUpdated(address, address);

    function initialize(address _owner) public initializer {
        Ownable.initialize(_owner);
    }

    function setVaultFactory(address _vaultFactory) public onlyOwner {
        vaultFactory = _vaultFactory;

        emit VaultFactorySet(vaultFactory);
    }

    function updateVault(address vault) public {
        Vault vaultContract = Vault(vault);

        require(vaultContract.isWhitelistAdmin(msg.sender), "Sender is not the vault's admin");

        vaults[msg.sender] = vault;

        emit VaultUpdated(msg.sender, address(vaultContract));
    }
}
