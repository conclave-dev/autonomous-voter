// contracts/StrategyFactory.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "./App.sol";
import "./interfaces/IArchive.sol";
import "./ProxyAdmin.sol";

contract StrategyFactory is Initializable {
    App public app;
    IArchive public archive;

    event InstanceCreated(address);
    event AdminCreated(address);
    event InstanceArchived(address, address);

    function initialize(App _app, IArchive _archive) public initializer {
        app = _app;
        archive = _archive;
    }

    function createInstance(bytes memory _data) public payable {
        address strategyOwner = msg.sender;

        // Create a proxy admin for managing the new strategy instance's upgradeability
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        proxyAdmin.initialize(app, strategyOwner);
        address adminAddress = address(proxyAdmin);

        // string memory packageName = "autonomous-voter";
        string memory contractName = "Strategy";

        // Create the actual strategy instance
        address strategyAddress = address(
            app.create.value(msg.value)(contractName, adminAddress, _data)
        );

        emit InstanceCreated(strategyAddress);

        emit AdminCreated(adminAddress);

        archive.updateStrategy(strategyAddress, strategyOwner);

        emit InstanceArchived(strategyAddress, strategyOwner);
    }
}
