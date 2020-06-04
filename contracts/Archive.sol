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

    function _isVaultOwner(address vault, address account) internal view {
        require(
            Vault(vault).owner() == account,
            "Account is not the vault owner"
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
}
