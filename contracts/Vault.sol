// contracts/Vault.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./celo/common/UsingRegistry.sol";
import "./celo/common/libraries/LinkedList.sol";

contract Vault is UsingRegistry {
    using SafeMath for uint256;
    using LinkedList for LinkedList.List;

    address public proxyAdmin;
    ILockedGold public lockedGold;

    // Fallback function so the vault can accept incoming withdrawal/reward transfers
    function() external payable {}

    function initialize(
        address registry_,
        address archive_,
        address owner_,
        address proxyAdmin_
    ) public payable initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
        Ownable.initialize(owner_);

        lockedGold = getLockedGold();

        _setProxyAdmin(proxyAdmin_);
        getAccounts().createAccount();
        deposit();
    }

    function setProxyAdmin(address admin) external onlyOwner {
        _setProxyAdmin(admin);
    }

    function _setProxyAdmin(address admin) internal {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function getBalance()
        public
        view
        returns (uint256 voting, uint256 nonvoting)
    {
        voting = lockedGold.getAccountTotalLockedGold(address(this)).sub(
            nonvoting
        );
        nonvoting = lockedGold.getAccountNonvotingLockedGold(address(this));

        return (voting, nonvoting);
    }

    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than zero");

        // Immediately lock the deposit
        lockedGold.lock.value(msg.value)();
    }
}
