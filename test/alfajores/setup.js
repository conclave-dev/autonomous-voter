const { assert } = require('chai').use(require('chai-as-promised'));
const { forEach } = require('lodash');
const {
  alfajoresRpcAPI,
  alfajoresPrimaryAccount,
  alfajoresSecondaryAccount,
  registryContractAddress
} = require('../../config');
const { setUpGlobalTestVariables, setUpGlobalTestContracts } = require('../util');

before(async function () {
  this.primarySender = alfajoresPrimaryAccount;
  this.secondarySender = alfajoresSecondaryAccount;
  this.registryContractAddress = registryContractAddress;

  // Add variables to test execution context
  forEach(await setUpGlobalTestVariables(alfajoresRpcAPI, this.primarySender), (value, key) => {
    this[key] = value;
  });

  // Retrieve test contracts and add to test execution context
  forEach(
    await setUpGlobalTestContracts({
      archive: this.archive,
      contracts: this.contracts,
      primarySender: this.primarySender,
      secondarySender: this.secondarySender,
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
