// contracts/VaultAdmin.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/application/App.sol";
import "@openzeppelin/upgrades/contracts/upgradeability/AdminUpgradeabilityProxy.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/WhitelistAdminRole.sol";
import "./Vault.sol";


contract VaultAdmin is WhitelistAdminRole {
    App private app;

    function initialize(App _app, address _owner) public initializer {
        WhitelistAdminRole.initialize(_owner);
        app = _app;
    }

    function upgradeVault(AdminUpgradeabilityProxy _proxy)
        public
        onlyWhitelistAdmin
    {
        // Check if the sender has the right to upgrade the vault proxy
        require(Vault(address(_proxy)).isWhitelistAdmin(msg.sender));

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
