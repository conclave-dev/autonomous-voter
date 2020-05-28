// contracts/Vault.sol
pragma solidity ^0.5.0;

import '@openzeppelin/upgrades/contracts/Initializable.sol';
import '@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol';

contract Archive is Initializable, Ownable {
  address public vaultFactory;

  function initialize(address _owner) public initializer {
    Ownable.initialize(_owner);
  }

  function setVaultFactory(address _vaultFactory) public onlyOwner {
    vaultFactory = _vaultFactory;
  }
}
