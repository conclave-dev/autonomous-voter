// contracts/VaultFactory.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "./App.sol";
import "./Portfolio.sol";
import "./ProxyAdmin.sol";

contract VaultFactory is Initializable {
    App public app;
    Portfolio public portfolio;

    function initialize(App app_, Portfolio portfolio_) public initializer {
        app = app_;
        portfolio = portfolio_;
    }

    function createInstance(
        string calldata packageName,
        string calldata contractName,
        address registry
    ) external payable {
        address vaultOwner = msg.sender;

        // Create a vault admin for managing the user's vault upgradeability
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        proxyAdmin.initialize(app, vaultOwner);
        address adminAddress = address(proxyAdmin);

        // Create the actual vault instance
        address vaultAddress = address(
            app.create(
                packageName,
                contractName,
                adminAddress,
                abi.encodeWithSignature(
                    "initialize(address,address,address,address)",
                    registry,
                    address(portfolio),
                    vaultOwner,
                    adminAddress
                )
            )
        );

        portfolio.setVaultByOwner(vaultOwner, vaultAddress);
    }
}
