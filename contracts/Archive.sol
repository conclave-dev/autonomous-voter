// contracts/Archive.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./Vault.sol";


contract Archive is Initializable, Ownable {
    address public vaultFactory;
    mapping(address => address) public vaults;

    event VaultFactorySet(address);
    event VaultUpdated(address, address);

    modifier onlyVaultFactory() {
        require(msg.sender == vaultFactory, "Sender is not vault factory");
        _;
    }

    function initialize(address _owner) public initializer {
        Ownable.initialize(_owner);
    }

    function setVaultFactory(address _vaultFactory) public onlyOwner {
        vaultFactory = _vaultFactory;

        emit VaultFactorySet(vaultFactory);
    }

    function _isVaultAdmin(address vault, address vaultAdmin) internal view {
        require(
            Vault(vault).isWhitelistAdmin(vaultAdmin),
            "Admin is not whitelisted on vault"
        );
    }

    function updateVault(address vault, address vaultAdmin)
        public
        onlyVaultFactory
    {
        _isVaultAdmin(vault, vaultAdmin);

        vaults[vaultAdmin] = vault;

        emit VaultUpdated(msg.sender, vault);
    }
}
