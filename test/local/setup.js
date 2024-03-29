const { assert } = require('chai').use(require('chai-as-promised'));
const { forEach } = require('lodash');
const { localRpcAPI, localPrimaryAccount, localSecondaryAccount, localThirdAccount } = require('../../config');
const { setUpGlobalTestVariables, setUpGlobalTestContracts } = require('../util');

before(async function () {
  this.primarySender = localPrimaryAccount;
  this.secondarySender = localSecondaryAccount;
  this.thirdSender = localThirdAccount;

  // Add variables to test execution context
  forEach(await setUpGlobalTestVariables(localRpcAPI, this.primarySender), (value, key) => {
    this[key] = value;
  });

  // Retrieve test contracts and add to test execution context
  forEach(await setUpGlobalTestContracts(this), (value, key) => {
    this[key] = value;
  });
});

module.exports = {
  assert
};
