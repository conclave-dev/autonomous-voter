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

    function _isVaultAdmin(address vault) internal view {
        require(
            Vault(vault).isWhitelistAdmin(msg.sender),
            "Sender is not the vault admin"
        );
    }

    function updateVault(address vault) public {
        _isVaultAdmin(vault);
        vaults[msg.sender] = vault;
        emit VaultUpdated(msg.sender, vault);
    }
}
