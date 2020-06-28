const { deployContracts, contractHasUpdates } = require('./util');

const App = artifacts.require('App');
const Vault = artifacts.require('Vault');
const VoteManager = artifacts.require('VoteManager');
const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const ManagerFactory = artifacts.require('ManagerFactory');

const contracts = [App, Vault, VoteManager, Archive, VaultFactory, ManagerFactory];

module.exports = async (deployer, network) => {
  await deployContracts(deployer, network, contracts);

  // Force deployment of factories if Archive was updated
  const archiveUpdated = await contractHasUpdates(deployer, network, Archive);

  if (archiveUpdated) {
    // These contracts must be re-deployed if Archive changes (which is always, atm) as they set the Archive address
    // when initializing. TODO: Replace initialize with setter fns to update instead of re-deploying
    await deployer.deploy(VaultFactory);
    await deployer.deploy(ManagerFactory);
  }
};
