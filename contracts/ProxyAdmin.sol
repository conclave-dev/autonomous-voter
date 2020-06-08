// contracts/ProxyAdmin.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/upgradeability/BaseAdminUpgradeabilityProxy.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";

import "./App.sol";

contract ProxyAdmin is Ownable {
    App private app;

    function initialize(App _app, address _owner) public initializer {
        Ownable.initialize(_owner);
        app = _app;
    }

    function upgradeProxy(
        BaseAdminUpgradeabilityProxy _proxy,
        address implementation
    ) public onlyOwner {
        _proxy.upgradeTo(implementation);
    }
}
