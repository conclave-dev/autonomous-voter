// contracts/Archive.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./Vault.sol";
import "./VaultAdmin.sol";


contract Archive is Initializable, Ownable {
    address public vaultFactory;
    mapping(address => address) public vaults;
    mapping(address => address) public vaultAdmins;

    event VaultFactorySet(address);
    event VaultUpdated(address, address);
    event VaultAdminUpdated(address, address);

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

    function _isVaultOwner(address vault, address account) internal view {
        require(
            Vault(vault).isWhitelistAdmin(account),
            "Account is not whitelisted on vault"
        );
    }

    function _isVaultAdminOwner(address admin, address account) internal view {
        require(
            VaultAdmin(admin).isWhitelistAdmin(account),
            "Account is not whitelisted on vault admin"
        );
    }

    function updateVault(address vault, address account)
        public
        onlyVaultFactory
    {
        _isVaultOwner(vault, account);

        vaults[account] = vault;

        emit VaultUpdated(msg.sender, vault);
    }

    function updateVaultAdmin(address admin, address account)
        public
        onlyVaultFactory
    {
        _isVaultAdminOwner(admin, account);

        vaultAdmins[account] = admin;

        emit VaultAdminUpdated(msg.sender, admin);
    }
}
