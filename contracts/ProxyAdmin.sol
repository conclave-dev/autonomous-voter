// contracts/ProxyAdmin.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/upgradeability/BaseAdminUpgradeabilityProxy.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";

import "./App.sol";

contract ProxyAdmin is Ownable {
    App public app;

    function initialize(App _app, address owner_) public initializer {
        Ownable.initialize(owner_);
        app = _app;
    }

    function upgradeProxyImplementation(
        BaseAdminUpgradeabilityProxy proxy,
        address implementation
    ) external onlyOwner {
        proxy.upgradeTo(implementation);
    }
}
