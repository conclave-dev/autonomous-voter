// contracts/VaultFactory.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/upgrades/contracts/application/App.sol";
import "./interfaces/IArchive.sol";
import './interfaces/IVault.sol';


contract VaultFactory is Initializable {
    uint256 public constant minimumDeposit = 100000000000000000;

    App private app;
    IArchive public archive;

    event InstanceCreated(address);
    event InstanceArchived(address, address);

    function initialize(App _app, IArchive _archive) public initializer {
        app = _app;
        archive = _archive;
    }

    function createInstance(bytes memory _data) public payable {
        require(msg.value >= minimumDeposit, 'Insufficient funds for initial deposit');

        string memory packageName = "autonomous-voter";
        string memory contractName = "Vault";
        address admin = msg.sender;

        address vaultAddress = address(app.create(packageName, contractName, admin, _data));

        // Initiate the initial deposit procedure
        IVault vault = IVault(vaultAddress);
        vault.deposit.value(msg.value)();

        emit InstanceCreated(vaultAddress);

        archive.updateVault(vaultAddress, admin);

        emit InstanceArchived(vaultAddress, admin);
    }
}
