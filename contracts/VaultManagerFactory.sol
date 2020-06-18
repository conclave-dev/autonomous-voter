// contracts/VaultManagerFactory.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "./App.sol";
import "./Archive.sol";
import "./ProxyAdmin.sol";

contract VaultManagerFactory is Initializable {
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
        address vaultManagerOwner = msg.sender;

        // Create a proxy admin for managing the new vault manager instance's upgradeability
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        proxyAdmin.initialize(app, vaultManagerOwner);
        address adminAddress = address(proxyAdmin);

        // Create the actual vault manager instance
        address vaultManagerAddress = address(
            app.create.value(msg.value)(
                contractName,
                adminAddress,
                abi.encodeWithSignature(
                    "initialize(address,address,address,uint256,uint256)",
                    address(archive),
                    vaultManagerOwner,
                    adminAddress,
                    sharePercentage,
                    minimumGold
                )
            )
        );

        archive.associateVaultManagerWithOwner(
            vaultManagerAddress,
            vaultManagerOwner
        );
    }
}
