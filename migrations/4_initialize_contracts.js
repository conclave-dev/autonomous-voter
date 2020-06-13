const App = artifacts.require('App');
const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const VaultManagerFactory = artifacts.require('VaultManagerFactory');
const { registryContractAddress } = require('../config');

module.exports = (deployer) =>
  deployer.then(async () => {
    const app = await App.deployed();
    const archive = await Archive.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const vaultManagerFactory = await VaultManagerFactory.deployed();

    await app.initialize();
    await archive.initialize(registryContractAddress);
    await vaultFactory.initialize(app.address, archive.address);
    await vaultManagerFactory.initialize(app.address, archive.address);
  });
