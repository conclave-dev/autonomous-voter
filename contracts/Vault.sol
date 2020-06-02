// contracts/Vault.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/WhitelistAdminRole.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./celo/common/UsingRegistry.sol";


contract Vault is UsingRegistry, WhitelistAdminRole {
    event UserDeposit(uint256);

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
        _depositGold();
    }

    function getUnmanagedGold() public view returns (uint256) {
        return getLockedGold().getAccountNonvotingLockedGold(address(this));
    }

    function _registerAccount() internal {
        require(
            getAccounts().createAccount(),
            "Failed to register vault account"
        );
    }

    function _depositGold() internal {
        // Immediately lock the deposit
        getLockedGold().lock.value(msg.value)();
        emit UserDeposit(msg.value);
    }
}
