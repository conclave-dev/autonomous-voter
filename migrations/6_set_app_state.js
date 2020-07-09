const App = artifacts.require('App');
const ImplementationDirectory = artifacts.require('ImplementationDirectory');
const Package = artifacts.require('Package');
const Vault = artifacts.require('Vault');
const VoteManager = artifacts.require('VoteManager');
const { packageName } = require('../config');

module.exports = (deployer) =>
  deployer.then(async () => {
    const app = await App.deployed();
    const directory = await ImplementationDirectory.deployed();
    const package = await Package.deployed();

    const { address: vaultAddress } = await Vault.deployed();
    const { address: managerAddress } = await VoteManager.deployed();
    const hasVault = (await directory.getImplementation('Vault')) === vaultAddress;
    const hasVoteManager = (await directory.getImplementation('VoteManager')) === managerAddress;

    if (!hasVault) {
      await directory.setImplementation('Vault', vaultAddress);
    }

    if (!hasVoteManager) {
      await directory.setImplementation('VoteManager', managerAddress);
    }

    await package.addVersion([1, 0, 0], directory.address, '0x0');
    await app.setPackage(packageName, package.address, [1, 0, 0]);
  });
