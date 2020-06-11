// contracts/VaultFactory.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "./App.sol";
import "./interfaces/IArchive.sol";
import "./ProxyAdmin.sol";

contract VaultFactory is Initializable {
    uint256 public constant MINIMUM_DEPOSIT = 100000000000000000;

    App public app;
    IArchive public archive;

    function initialize(App _app, IArchive _archive) public initializer {
        app = _app;
        archive = _archive;
    }

    function createInstance(address _registry, address _archive)
        public
        payable
    {
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
        string memory contractName = "Vault";

        // Create the actual vault instance
        address vaultAddress = address(
            app.create.value(msg.value)(
                contractName,
                adminAddress,
                abi.encodeWithSignature(
                    "initialize(address,address,address,address)",
                    _registry,
                    _archive,
                    vaultOwner,
                    adminAddress
                )
            )
        );

        archive.setVault(vaultAddress, vaultOwner);
    }
}
