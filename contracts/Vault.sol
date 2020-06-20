// contracts/Vault.sol
pragma solidity ^0.5.8;

import "./modules/VoteManagement.sol";
import "./celo/common/UsingRegistry.sol";
import "./Archive.sol";
import "./celo/common/libraries/LinkedList.sol";

contract Vault is UsingRegistry, VoteManagement {
    address public proxyAdmin;

    // Pending withdrawals (hash of pending withdrawal's initiator, value, timestamp)
    LinkedList.List pendingWithdrawals;

    function initialize(
        address registry_,
        address archive_,
        address owner_,
        address proxyAdmin_
    ) public payable initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
        Ownable.initialize(owner_);

        proxyAdmin = proxyAdmin_;
        archive = Archive(archive_);

        setRegistryContracts();

        getAccounts().createAccount();
        deposit();
    }

    function setRegistryContracts() internal {
        election = getElection();
        lockedGold = getLockedGold();
    }

    function setProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than zero");

        // Immediately lock the deposit
        lockedGold.lock.value(msg.value)();
    }
}
