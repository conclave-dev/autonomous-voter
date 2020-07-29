const { assert } = require('chai').use(require('chai-as-promised'));
const { forEach } = require('lodash');
const { localRpcAPI, localPrimaryAccount, localSecondaryAccount, registryContractAddress } = require('../../config');
const { setUpGlobalTestVariables, setUpGlobalTestContracts } = require('../util');

before(async function () {
  this.primarySender = localPrimaryAccount;
  this.secondarySender = localSecondaryAccount;
  this.registryContractAddress = registryContractAddress;

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
      mockBank: this.mockBank,
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
