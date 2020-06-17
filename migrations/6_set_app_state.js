const App = artifacts.require('App');
const Vault = artifacts.require('Vault');
const VaultManager = artifacts.require('VaultManager');
const VaultFactory = artifacts.require('VaultFactory');
const VaultManagerFactory = artifacts.require('VaultManagerFactory');
const MockVault = artifacts.require('MockVault');
const MockVaultFactory = artifacts.require('MockVaultFactory');

module.exports = (deployer) =>
  deployer.then(async () => {
    const app = await App.deployed();
    const { address: vaultAddress } = await Vault.deployed();
    const { address: vaultManagerAddress } = await VaultManager.deployed();
    const { address: vaultFactoryAddress } = await VaultFactory.deployed();
    const { address: vaultManagerFactoryAddress } = await VaultManagerFactory.deployed();
    const hasVault = (await app.contractImplementations('Vault')) === vaultAddress;
    const hasVaultManager = (await app.contractImplementations('VaultManager')) === vaultManagerAddress;
    const hasVaultFactory = (await app.contractFactories('Vault')) === vaultFactoryAddress;
    const hasVaultManagerFactory = (await app.contractFactories('VaultManager')) === vaultManagerFactoryAddress;

    if (!hasVault) {
      await app.setContractImplementation('Vault', vaultAddress);
    }

    if (!hasVaultManager) {
      await app.setContractImplementation('VaultManager', vaultManagerAddress);
    }

    if (!hasVaultFactory) {
      await app.setContractFactory('Vault', vaultFactoryAddress);
    }

    if (!hasVaultManagerFactory) {
      await app.setContractFactory('VaultManager', vaultManagerFactoryAddress);
    }

    const { address: mockVaultAddress } = await MockVault.deployed();
    const { address: mockVaultFactoryAddress } = await MockVaultFactory.deployed();
    const hasMockVault = (await app.contractImplementations('MockVault')) === mockVaultAddress;
    const hasMockVaultFactory = (await app.contractFactories('MockVault')) === mockVaultFactoryAddress;

    if (!hasMockVault) {
      await app.setContractImplementation('MockVault', mockVaultAddress);
    }

    if (!hasMockVaultFactory) {
      await app.setContractFactory('MockVault', mockVaultFactoryAddress);
    }
  });
