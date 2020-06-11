// contracts/ProxyAdmin.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/upgradeability/BaseAdminUpgradeabilityProxy.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";

import "./App.sol";

contract ProxyAdmin is Ownable {
    App private app;

    function initialize(App _app, address owner) public initializer {
        Ownable.initialize(owner);
        app = _app;
    }

    function upgradeProxy(
        BaseAdminUpgradeabilityProxy proxy,
        address implementation
    ) public onlyOwner {
        proxy.upgradeTo(implementation);
    }
}
