const Promise = require('bluebird');
const { registryContractAddress } = require('../config');

const App = artifacts.require('App');
const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const VaultManagerFactory = artifacts.require('VaultManagerFactory');
const MockVaultFactory = artifacts.require('MockVaultFactory');
const MockArchive = artifacts.require('MockArchive');

module.exports = (deployer) =>
  deployer.then(async () => {
    const app = await App.deployed();
    const archive = await Archive.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const vaultManagerFactory = await VaultManagerFactory.deployed();
    const mockArchive = await MockArchive.deployed();
    const mockVaultFactory = await MockVaultFactory.deployed();
    const contractInitializers = [
      { contract: 'App', fn: async () => await app.initialize() },
      { contract: 'Archive', fn: async () => await archive.initialize(registryContractAddress) },
      {
        contract: 'VaultFactory',
        fn: async () => await vaultFactory.initialize(app.address, archive.address, 'Vault')
      },
      {
        contract: 'VaultManagerFactory',
        fn: async () => await vaultManagerFactory.initialize(app.address, archive.address, 'VaultManager')
      },
      { contract: 'MockArchive', fn: async () => await mockArchive.initialize(registryContractAddress) },
      {
        contract: 'MockVaultFactory',
        fn: async () => await mockVaultFactory.initialize(app.address, mockArchive.address, 'MockVault')
      }
    ];

    await Promise.each(contractInitializers, async ({ contract, fn }) => {
      try {
        await fn();
      } catch (err) {
        console.error(`Error calling ${contract} initializer: ${err}`);
      }
    });
  });
