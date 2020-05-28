// contracts/Vault.sol
pragma solidity ^0.5.0;

import '@openzeppelin/upgrades/contracts/Initializable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol';


contract Archive is Initializable, Ownable {
  address public vaultFactory;
  mapping(address => address) public vaults;

  event VaultFactorySet(address);
  event VaultUpdated(address);

  function initialize(address _owner) public initializer {
    Ownable.initialize(_owner);
  }

  function setVaultFactory(address _vaultFactory) public onlyOwner {
    vaultFactory = _vaultFactory;

    emit VaultFactorySet(vaultFactory);
  }

  function updateVault(address vault) public {
    vaults[msg.sender] = vault;

    emit VaultUpdated(msg.sender);
  }
}
