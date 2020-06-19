const App = artifacts.require('App');
const Vault = artifacts.require('Vault');
const VotingVaultManager = artifacts.require('VotingVaultManager');
const VaultFactory = artifacts.require('VaultFactory');
const VotingVaultManagerFactory = artifacts.require('VotingVaultManagerFactory');

module.exports = (deployer) =>
  deployer.then(async () => {
    const app = await App.deployed();
    const { address: vaultAddress } = await Vault.deployed();
    const { address: vaultManagerAddress } = await VotingVaultManager.deployed();
    const { address: vaultFactoryAddress } = await VaultFactory.deployed();
    const { address: vaultManagerFactoryAddress } = await VotingVaultManagerFactory.deployed();
    const hasVault = (await app.contractImplementations('Vault')) === vaultAddress;
    const hasVotingVaultManager = (await app.contractImplementations('VotingVaultManager')) === vaultManagerAddress;
    const hasVaultFactory = (await app.contractFactories('Vault')) === vaultFactoryAddress;
    const hasVotingVaultManagerFactory =
      (await app.contractFactories('VotingVaultManager')) === vaultManagerFactoryAddress;

    if (!hasVault) {
      await app.setContractImplementation('Vault', vaultAddress);
    }

    if (!hasVotingVaultManager) {
      await app.setContractImplementation('VotingVaultManager', vaultManagerAddress);
    }

    if (!hasVaultFactory) {
      await app.setContractFactory('Vault', vaultFactoryAddress);
    }

    if (!hasVotingVaultManagerFactory) {
      await app.setContractFactory('VotingVaultManager', vaultManagerFactoryAddress);
    }
  });
