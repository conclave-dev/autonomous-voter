// contracts/Vault.sol
pragma solidity ^0.5.8;

import "./celo/common/UsingRegistry.sol";
import "./Archive.sol";
import "./VaultManager.sol";

contract Vault is UsingRegistry {
    using SafeMath for uint256;

    Archive private archive;
    address public proxyAdmin;

    struct Managers {
        VotingVaultManager voting;
    }

    struct VotingVaultManager {
        address contractAddress;
        uint256 rewardSharePercentage;
    }

    Managers private managers;

    function initialize(
        address registry_,
        Archive archive_,
        address owner_,
        address admin
    ) public payable initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
        Ownable.initialize(owner_);

        archive = archive_;
        proxyAdmin = admin;
        _registerAccount();
        deposit();
    }

    // Fallback function so the vault can accept incoming withdrawal/reward transfers
    function() external payable {}

    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than zero");

        // Immediately lock the deposit
        getLockedGold().lock.value(msg.value)();
    }

    // Gets the Vault's locked gold amount (both voting and nonvoting)
    function getManageableBalance() public view returns (uint256) {
        return getLockedGold().getAccountTotalLockedGold(address(this));
    }

    // Gets the Vault's nonvoting locked gold amount
    function getNonvotingBalance() public view returns (uint256) {
        return getLockedGold().getAccountNonvotingLockedGold(address(this));
    }

    function verifyVaultManager(VaultManager manager) internal view {
        require(
            archive.hasVaultManager(manager.owner(), address(manager)),
            "Voting manager is invalid"
        );
    }

    function setVotingVaultManager(VaultManager manager) external onlyOwner {
        verifyVaultManager(manager);

        managers.voting.contractAddress = address(manager);
        managers.voting.rewardSharePercentage = manager.rewardSharePercentage();

        manager.registerVault(this);
    }

    function getVotingVaultManager() public view returns (address, uint256) {
        return (
            managers.voting.contractAddress,
            managers.voting.rewardSharePercentage
        );
    }

    function initiateWithdrawal(uint256 amount) external onlyOwner {
        require(
            amount > 0 && amount <= getNonvotingBalance(),
            "Invalid amount specified"
        );

        getLockedGold().unlock(amount);
    }

    function cancelWithdrawal(uint256 index, uint256 amount)
        external
        onlyOwner
    {
        require(amount > 0, "Invalid amount specified");

        getLockedGold().relock(index, amount);
    }

    function withdraw(uint256 index) external onlyOwner {
        (, uint256[] memory timestamps) = getLockedGold().getPendingWithdrawals(
            address(this)
        );

        require(index < timestamps.length, "Index out-of-bound");
        require(timestamps[index] < now, "Withdrawal is not yet available");

        // Proceed to the fund transfer only if the withdrawal has been fully unlocked
        getLockedGold().withdraw(index);
    }

    function setProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function _registerAccount() internal {
        require(
            getAccounts().createAccount(),
            "Failed to register vault account"
        );
    }
}
