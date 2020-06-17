// contracts/VaultFactory.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "./App.sol";
import "./Archive.sol";
import "./ProxyAdmin.sol";

contract VaultFactory is Initializable {
    uint256 public constant MINIMUM_DEPOSIT = 100000000000000000;

    App public app;
    Archive public archive;
    string public contractName;

    function initialize(
        App app_,
        Archive archive_,
        string memory contractName_
    ) public initializer {
        app = app_;
        archive = archive_;
        contractName = contractName_;
    }

    function createInstance(address registry) public payable {
        require(
            msg.value >= MINIMUM_DEPOSIT,
            "Insufficient funds for initial deposit"
        );

        address vaultOwner = msg.sender;

        // Create a vault admin for managing the user's vault upgradeability
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        proxyAdmin.initialize(app, vaultOwner);
        address adminAddress = address(proxyAdmin);

        // string memory packageName = "autonomous-voter";

        // Create the actual vault instance
        address vaultAddress = address(
            app.create.value(msg.value)(
                contractName,
                adminAddress,
                abi.encodeWithSignature(
                    "initialize(address,address,address,address)",
                    registry,
                    address(archive),
                    vaultOwner,
                    adminAddress
                )
            )
        );

        archive.associateVaultWithOwner(vaultAddress, vaultOwner);
    }
}
