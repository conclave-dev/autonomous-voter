// contracts/Vault.sol
pragma solidity ^0.5.8;

import "./celo/common/UsingRegistry.sol";
import "./interfaces/IArchive.sol";
import "./Strategy.sol";

contract Vault is UsingRegistry {
    IArchive private archive;
    address public proxyAdmin;

    struct Managers {
        VotingManager voting;
    }

    struct VotingManager {
        address contractAddress;
        uint256 rewardSharePercentage;
    }

    Managers private managers;

    function initialize(
        address _registry,
        IArchive _archive,
        address owner,
        address admin
    ) public payable initializer {
        UsingRegistry.initializeRegistry(msg.sender, _registry);
        Ownable.initialize(owner);

        archive = _archive;
        proxyAdmin = admin;
        _registerAccount();
        deposit();
    }

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

    function validateVotingManager(Strategy strategy) internal view {
        require(
            archive.getStrategy(strategy.owner()) == address(strategy),
            "Voting manager is invalid"
        );
    }

    function setVotingManager(Strategy strategy) external onlyOwner {
        validateVotingManager(strategy);

        managers.voting.contractAddress = address(strategy);
        managers.voting.rewardSharePercentage = strategy
            .rewardSharePercentage();

        strategy.registerVault(this);
    }

    function getVotingManager() public view returns (address, uint256) {
        return (
            managers.voting.contractAddress,
            managers.voting.rewardSharePercentage
        );
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
