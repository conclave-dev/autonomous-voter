// contracts/Vault.sol
pragma solidity ^0.5.0;

import '@openzeppelin/upgrades/contracts/Initializable.sol';
import './celo/common/UsingRegistry.sol';

contract Vault is UsingRegistry {
  event UserDeposit(uint256);

  function initialize(address registryAddress) public initializer {
    UsingRegistry.initializeRegistry(msg.sender, registryAddress);
    require(getAccounts().createAccount(), "Failed to register vault account");
  }

  function deposit() public payable {
    // Immediately lock the deposit
    getLockedGold().lock.value(msg.value)();
    emit UserDeposit(msg.value);
  }

  function getUnmanagedGold() public view returns (uint256) {
    return getLockedGold().getAccountNonvotingLockedGold(address(this));
  }
}
