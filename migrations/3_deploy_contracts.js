const { deployContracts, contractHasUpdates } = require('./util');

const App = artifacts.require('App');
const ImplementationDirectory = artifacts.require('ImplementationDirectory');
const Package = artifacts.require('Package');
const Vault = artifacts.require('Vault');
const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const Bank = artifacts.require('Bank');
const Portfolio = artifacts.require('Portfolio');

const contracts = [ImplementationDirectory, Package, Vault, Archive, VaultFactory, Bank, Portfolio];

module.exports = async (deployer, network) => {
  // Handle `App` deployment separately since there seems to be a bug for contracts with defined but empty constructor
  // when calling Truffle's deployer while including options (one of which is `overwrite`)
  // so we would check externally and omit the usage of `overwrite` for its deployment
  if (contractHasUpdates(deployer, network, App)) {
    await deployer.deploy(App);
  }

  // Handle the rest of the contracts
  await deployContracts(deployer, network, contracts);

  // Force deployment of factories if Archive was updated
  const archiveUpdated = await contractHasUpdates(deployer, network, Archive);

  if (archiveUpdated) {
    // These contracts must be re-deployed if Archive changes (which is always, atm) as they set the Archive address
    // when initializing. TODO: Replace initialize with setter fns to update instead of re-deploying
    await deployer.deploy(VaultFactory);
  }
};
