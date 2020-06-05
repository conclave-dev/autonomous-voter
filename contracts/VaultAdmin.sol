// contracts/VaultAdmin.sol
pragma solidity ^0.5.8;

import "./App.sol";
import "@openzeppelin/upgrades/contracts/upgradeability/BaseAdminUpgradeabilityProxy.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";


contract VaultAdmin is Ownable {
    App private app;

    function initialize(App _app, address _owner) public initializer {
        Ownable.initialize(_owner);
        app = _app;
    }

    function upgradeVault(
        BaseAdminUpgradeabilityProxy _proxy,
        address implementation
    ) public onlyOwner {
        _proxy.upgradeTo(implementation);
    }
}
