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

    function createInstance(uint256 sharePercentage, uint256 minimumGold)
        public
        payable
    {
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
                    "initialize(address,address,address,uint256,uint256)",
                    address(archive),
                    strategyOwner,
                    adminAddress,
                    sharePercentage,
                    minimumGold
                )
            )
        );

        archive.setStrategy(strategyAddress, strategyOwner);
    }
}
