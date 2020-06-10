// contracts/StrategyFactory.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "./App.sol";
import "./interfaces/IArchive.sol";
import "./ProxyAdmin.sol";

contract StrategyFactory is Initializable {
    App public app;
    IArchive public archive;

    function initialize(App _app, IArchive _archive) public initializer {
        app = _app;
        archive = _archive;
    }

    function createInstance(
        address _archive,
        address _owner,
        uint256 _sharePercentage,
        uint256 _minimumGold
    ) public payable {
        address strategyOwner = msg.sender;

        // Create a proxy admin for managing the new strategy instance's upgradeability
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        proxyAdmin.initialize(app, strategyOwner);
        address adminAddress = address(proxyAdmin);

        // string memory packageName = "autonomous-voter";
        string memory contractName = "Strategy";

        // Create the actual strategy instance
        address strategyAddress = address(
            app.create.value(msg.value)(
                contractName,
                adminAddress,
                abi.encodeWithSignature(
                    "initializeStrategy(address,address,address,uint256,uint256)",
                    _archive,
                    _owner,
                    adminAddress,
                    _sharePercentage,
                    _minimumGold
                )
            )
        );

        archive.setStrategy(strategyAddress, strategyOwner);
    }
}
