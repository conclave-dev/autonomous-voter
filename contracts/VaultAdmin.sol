// contracts/VaultAdmin.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/application/App.sol";
import "@openzeppelin/upgrades/contracts/upgradeability/BaseAdminUpgradeabilityProxy.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";


contract VaultAdmin is Ownable {
    App private app;

    function initialize(App _app, address _owner) public initializer {
        Ownable.initialize(_owner);
        app = _app;
    }

    function upgradeVault(BaseAdminUpgradeabilityProxy _proxy)
        public
        onlyOwner
    {
        string memory packageName = "autonomous-voter";
        string memory contractName = "Vault";

        // Proceed to direct the call to the vault proxy itself to start the upgrade
        address implementation = app.getImplementation(
            packageName,
            contractName
        );

        _proxy.upgradeTo(implementation);
    }
}
