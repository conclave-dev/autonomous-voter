const App = artifacts.require('App');
const Vault = artifacts.require('Vault');
const VaultManager = artifacts.require('VaultManager');
const VaultFactory = artifacts.require('VaultFactory');
const VaultManagerFactory = artifacts.require('VaultManagerFactory');

module.exports = (deployer) =>
  deployer.then(async () => {
    const app = await App.deployed();
    const { address: vaultAddress } = await Vault.deployed();
    const { address: vaultManagerAddress } = await VaultManager.deployed();
    const { address: vaultFactoryAddress } = await VaultFactory.deployed();
    const { address: vaultManagerFactoryAddress } = await VaultManagerFactory.deployed();

    await app.setContractImplementation('Vault', vaultAddress);
    await app.setContractImplementation('VaultManager', vaultManagerAddress);
    await app.setContractFactory('Vault', vaultFactoryAddress);
    await app.setContractFactory('VaultManager', vaultManagerFactoryAddress);
  });
