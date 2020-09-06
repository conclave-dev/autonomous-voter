// contracts/Vault.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./celo/common/UsingRegistry.sol";

contract Vault is UsingRegistry {
    using SafeMath for uint256;

    address public portfolio;
    address public proxyAdmin;

    function initialize(
        address registry_,
        address portfolio_,
        address owner_,
        address proxyAdmin_
    ) public initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
        Ownable.initialize(owner_);

        portfolio = portfolio_;

        _setProxyAdmin(proxyAdmin_);
        getAccounts().createAccount();
    }

    function setProxyAdmin(address admin) external onlyOwner {
        _setProxyAdmin(admin);
    }

    function _setProxyAdmin(address admin) internal {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }
}
