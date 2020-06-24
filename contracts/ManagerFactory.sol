pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "./App.sol";
import "./Archive.sol";
import "./ProxyAdmin.sol";

contract ManagerFactory is Initializable {
    App public app;
    Archive public archive;

    function initialize(App app_, Archive archive_) public initializer {
        app = app_;
        archive = archive_;
    }

    function createInstance(
        string memory contractName,
        uint256 sharePercentage,
        uint256 minimumGold
    ) public payable {
        address managerOwner = msg.sender;

        // Create a proxy admin for managing the new manager instance's upgradeability
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        proxyAdmin.initialize(app, managerOwner);
        address proxyAdminAddress = address(proxyAdmin);

        // Create the actual manager instance
        address manager = address(
            app.create.value(msg.value)(
                contractName,
                proxyAdminAddress,
                abi.encodeWithSignature(
                    "initialize(address,address,address,uint256,uint256)",
                    address(archive),
                    managerOwner,
                    proxyAdminAddress,
                    sharePercentage,
                    minimumGold
                )
            )
        );

        archive.associateManagerWithOwner(manager, managerOwner);
    }
}