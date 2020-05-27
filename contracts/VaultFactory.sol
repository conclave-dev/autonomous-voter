// contracts/VaultFactory.sol
pragma solidity ^0.5.0;

import '@openzeppelin/upgrades/contracts/Initializable.sol';
import '@openzeppelin/upgrades/contracts/application/App.sol';


contract VaultFactory is Initializable {
  App private app;

  event InstanceCreated(address);

  function initialize(App _app) public initializer {
    app = _app;
  }

  function createInstance(bytes memory _data) public {
    string memory packageName = 'autonomous-voter';
    string memory contractName = 'Vault';
    address admin = msg.sender;

    address vault = address(app.create(packageName, contractName, admin, _data));

    emit InstanceCreated(vault);
  }
}
