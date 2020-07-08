const { assert } = require('chai').use(require('chai-as-promised'));
const BigNumber = require('bignumber.js');
const { forEach } = require('lodash');
const { localRpcAPI } = require('../../config');
const { setUpGlobalTestVariables } = require('../util');

before(async function () {
  this.primarySender = '0x5409ED021D9299bf6814279A6A1411A7e866A631';
  this.secondarySender = '0x6Ecbe1DB9EF729CBe972C83Fb886247691Fb6beb';

  forEach(await setUpGlobalTestVariables(localRpcAPI, this.primarySender), (value, key) => {
    this[key] = value;
  });

  const getVaults = () => this.archive.getVaultsByOwner(this.primarySender);
  const getManagers = () => this.archive.getManagersByOwner(this.primarySender);
  const createVaultInstance = () =>
    this.vaultFactory.createInstance('Vault', this.registryContractAddress, {
      value: new BigNumber('1e17')
    });
  const createManagerInstance = () =>
    this.managerFactory.createInstance('VoteManager', this.managerCommission, this.minimumBalanceRequirement);

  // Conditionally create persistent test instances if they don't yet exist
  if (!(await getVaults()).length) {
    await createVaultInstance();
  }

  if (!(await getManagers()).length) {
    await createManagerInstance();
  }

  // New test instances
  await createVaultInstance();
  await createManagerInstance();

  const vaults = await getVaults();
  const managers = await getManagers();

  // Maintain state and used for voting tests
  this.persistentVaultInstance = await this.contracts.Vault.at(vaults[0]);
  this.persistentVoteManagerInstance = await this.contracts.VoteManager.at(managers[0]);
  this.vaultInstance = await this.contracts.Vault.at(vaults.pop());
  this.managerInstance = await this.contracts.VoteManager.at(managers.pop());
  this.proxyAdmin = await this.contracts.ProxyAdmin.at(await this.vaultInstance.proxyAdmin());
});

module.exports = {
  assert
};
