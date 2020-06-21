const App = artifacts.require('App');
const Vault = artifacts.require('Vault');
const VoteManager = artifacts.require('VoteManager');
const VaultFactory = artifacts.require('VaultFactory');
const ManagerFactory = artifacts.require('ManagerFactory');

module.exports = (deployer) =>
  deployer.then(async () => {
    const app = await App.deployed();
    const { address: vaultAddress } = await Vault.deployed();
    const { address: managerAddress } = await VoteManager.deployed();
    const { address: vaultFactoryAddress } = await VaultFactory.deployed();
    const { address: managerFactoryAddress } = await ManagerFactory.deployed();
    const hasVault = (await app.contractImplementations('Vault')) === vaultAddress;
    const hasVoteManager = (await app.contractImplementations('VoteManager')) === managerAddress;
    const hasVaultFactory = (await app.contractFactories('Vault')) === vaultFactoryAddress;
    const hasManagerFactory = (await app.contractFactories('VoteManager')) === managerFactoryAddress;

    if (!hasVault) {
      await app.setContractImplementation('Vault', vaultAddress);
    }

    if (!hasVoteManager) {
      await app.setContractImplementation('VoteManager', managerAddress);
    }

    if (!hasVaultFactory) {
      await app.setContractFactory('Vault', vaultFactoryAddress);
    }

    if (!hasManagerFactory) {
      await app.setContractFactory('VoteManager', managerFactoryAddress);
    }
  });
