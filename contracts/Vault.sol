// contracts/Vault.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/WhitelistAdminRole.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./celo/common/UsingRegistry.sol";


contract Vault is UsingRegistry, WhitelistAdminRole {
    event UserDeposit(uint256);

    function initialize(address registry, address admin) public initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry);
        _registerAccount();
        WhitelistAdminRole.initialize(admin);
    }

    function deposit() public payable {
        // Immediately lock the deposit
        getLockedGold().lock.value(msg.value)();
        emit UserDeposit(msg.value);
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
}
