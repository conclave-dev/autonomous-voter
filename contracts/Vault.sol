// contracts/Vault.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/WhitelistAdminRole.sol";
import "./celo/common/UsingRegistry.sol";


contract Vault is UsingRegistry, WhitelistAdminRole {
    event UserDeposit(uint256);

    uint256 public unmanagedGold;

    function initializeVault(address registry, address admin)
        public
        payable
        initializer
    {
        UsingRegistry.initializeRegistry(msg.sender, registry);
        WhitelistAdminRole.initialize(admin);
        _registerAccount();
        _depositGold();
    }

    function deposit() public payable onlyWhitelistAdmin {
        require(msg.value > 0, "Deposited funds must be larger than 0");

        _depositGold();
    }

    function _registerAccount() internal {
        require(
            getAccounts().createAccount(),
            "Failed to register vault account"
        );
    }

    function _depositGold() internal {
        // Update total unmanaged gold
        unmanagedGold += msg.value;

        // Immediately lock the deposit
        getLockedGold().lock.value(msg.value)();
        emit UserDeposit(msg.value);
    }
}
