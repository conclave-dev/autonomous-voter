const Vault = artifacts.require('Vault');
const VaultManager = artifacts.require('VaultManager');
const App = artifacts.require('App');
const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const VaultManagerFactory = artifacts.require('VaultManagerFactory');
const Promise = require('bluebird');

const contracts = [Vault, VaultManager, App, Archive, VaultFactory, VaultManagerFactory];

module.exports = async (deployer) => {
  await Promise.each(contracts, async (contract) => await deployer.deploy(contract));
};
