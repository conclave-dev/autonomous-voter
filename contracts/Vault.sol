// contracts/Product.sol
pragma solidity ^0.5.0;

import '@openzeppelin/upgrades/contracts/Initializable.sol';
import './celo/common/UsingRegistry.sol';

contract Vault is Initializable, UsingRegistry {
  function initialize(address registryAddress) public initializer {
    setRegistry(registryAddress);
  }
}
