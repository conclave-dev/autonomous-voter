// contracts/VaultFactory.sol
pragma solidity ^0.5.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/application/App.sol";
import "./interfaces/IArchive.sol";


contract VaultFactory is Initializable {
    App private app;
    IArchive public archive;

    event InstanceCreated(address);
    event InstanceArchived(address, address);

    function initialize(App _app, IArchive _archive) public initializer {
        app = _app;
        archive = _archive;
    }

    function createInstance(bytes memory _data) public {
        string memory packageName = "autonomous-voter";
        string memory contractName = "Vault";
        address admin = msg.sender;

        address vault = address(
            app.create(packageName, contractName, admin, _data)
        );

        emit InstanceCreated(vault);

        archive.updateVault(vault, admin);

        emit InstanceArchived(vault, admin);
    }
}
