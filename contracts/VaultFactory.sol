// contracts/VaultFactory.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/application/App.sol";
import "./interfaces/IArchive.sol";
import "./interfaces/IVault.sol";
import "./VaultAdmin.sol";


contract VaultFactory is Initializable {
    uint256 public constant MINIMUM_DEPOSIT = 100000000000000000;

    App private app;
    IArchive public archive;

    event InstanceCreated(address);
    event InstanceArchived(address, address);

    function initialize(App _app, IArchive _archive) public initializer {
        app = _app;
        archive = _archive;
    }

    function createInstance(bytes memory _data) public payable {
        require(
            msg.value >= MINIMUM_DEPOSIT,
            "Insufficient funds for initial deposit"
        );

        address vaultOwner = msg.sender;

        // Create a vault admin for managing the user's vault upgradeability
        VaultAdmin vaultAdmin = new VaultAdmin();
        vaultAdmin.initialize(app, vaultOwner);
        address adminAddress = address(vaultAdmin);

        string memory packageName = "autonomous-voter";
        string memory contractName = "Vault";

        // Create the actual vault instance
        address vaultAddress = address(
            app.create.value(msg.value)(
                packageName,
                contractName,
                adminAddress,
                _data
            )
        );

        emit InstanceCreated(vaultAddress);

        archive.updateVault(vaultAddress, vaultOwner);
        archive.updateVaultAdmin(adminAddress, vaultOwner);

        emit InstanceArchived(vaultAddress, vaultOwner);
    }
}
