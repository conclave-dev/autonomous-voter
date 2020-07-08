const { assert } = require('chai').use(require('chai-as-promised'));
const { forEach } = require('lodash');
const { localRpcAPI } = require('../../config');
const { setUpGlobalTestVariables, setUpGlobalTestContracts } = require('../util');

before(async function () {
  this.primarySender = '0x5409ED021D9299bf6814279A6A1411A7e866A631';
  this.secondarySender = '0x6Ecbe1DB9EF729CBe972C83Fb886247691Fb6beb';

  // Add variables to test execution context
  forEach(await setUpGlobalTestVariables(localRpcAPI, this.primarySender), (value, key) => {
    this[key] = value;
  });

  // Retrieve test contracts and add to test execution context
  forEach(
    await setUpGlobalTestContracts({
      archive: this.archive,
      contracts: this.contracts,
      primarySender: this.primarySender,
      vaultFactory: this.vaultFactory,
      managerFactory: this.managerFactory,
      managerCommission: this.managerCommission,
      minimumBalanceRequirement: this.minimumBalanceRequirement
    }),
    (value, key) => {
      this[key] = value;
    }
  );
});

module.exports = {
  assert
};
