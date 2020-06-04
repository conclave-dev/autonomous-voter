// contracts/Vault.sol
pragma solidity ^0.5.8;

import "./celo/common/UsingRegistry.sol";


contract Vault is UsingRegistry {
    event UserDeposit(uint256);

    address public vaultAdmin;
    uint256 public unmanagedGold;

    function initializeVault(address registry, address owner)
        public
        payable
        initializer
    {
        UsingRegistry.initializeRegistry(msg.sender, registry);
        Ownable.initialize(owner);

        _registerAccount();
        _depositGold();
    }

    function deposit() public payable onlyOwner {
        require(msg.value > 0, "Deposited funds must be larger than 0");
        _depositGold();
    }

    function updateVaultAdmin(address admin) external onlyOwner {
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
