const App = artifacts.require('App');
const ImplementationDirectory = artifacts.require('ImplementationDirectory');
const Package = artifacts.require('Package');
const Vault = artifacts.require('Vault');
const VoteManager = artifacts.require('VoteManager');
const { packageName, packageVersion } = require('../config');

module.exports = (deployer) =>
  deployer.then(async () => {
    const app = await App.deployed();
    const directory = await ImplementationDirectory.deployed();
    const package = await Package.deployed();

    const { address: vaultAddress } = await Vault.deployed();
    const { address: managerAddress } = await VoteManager.deployed();

    const hasDirectory = (await package.getContract(packageVersion)) === directory.address;
    const hasPackage = (await app.getPackage(packageName))[0] === package.address;
    const hasVault = (await directory.getImplementation('Vault')) === vaultAddress;
    const hasVoteManager = (await directory.getImplementation('VoteManager')) === managerAddress;

    if (!hasVault) {
      await directory.setImplementation('Vault', vaultAddress);
    }

    if (!hasVoteManager) {
      await directory.setImplementation('VoteManager', managerAddress);
    }

    if (!hasDirectory) {
      await package.addVersion(packageVersion, directory.address, '0x0');
    }

    if (!hasPackage) {
      await app.setPackage(packageName, package.address, packageVersion);
    }
  });
