// contracts/Vault.sol
pragma solidity ^0.5.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/WhitelistAdminRole.sol";
import "./celo/common/UsingRegistry.sol";


contract Vault is UsingRegistry, WhitelistAdminRole {
    function initialize(address registryAddress, address adminAddress) public initializer {
        UsingRegistry.initializeRegistry(msg.sender, registryAddress);

        require(
            getAccounts().createAccount(),
            "Failed to register vault account"
        );

        WhitelistAdminRole.initialize(adminAddress);
    }
}
