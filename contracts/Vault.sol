// contracts/Vault.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/WhitelistAdminRole.sol";
import "./celo/common/UsingRegistry.sol";


contract Vault is UsingRegistry, WhitelistAdminRole {
    event UserDeposit(uint256);

    address private vaultFactory;
    address private vaultAdmin;
    uint256 public unmanagedGold;

    function initializeVault(
        address registry,
        address admin,
        address factory
    ) public payable initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry);
        WhitelistAdminRole.initialize(admin);

        vaultFactory = factory;
        _registerAccount();
        _depositGold();
    }

    function deposit() public payable onlyWhitelistAdmin {
        require(msg.value > 0, "Deposited funds must be larger than 0");

        _depositGold();
    }

    function getVaultAdmin()
        external
        view
        onlyWhitelistAdmin
        returns (address)
    {
        return vaultAdmin;
    }

    function updateVaultAdmin(address admin) external {
        require(msg.sender == vaultFactory, "Sender is not vault factory");
        require(admin != address(0), "Invalid admin address");
        vaultAdmin = admin;
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
