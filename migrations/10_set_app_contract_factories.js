const App = artifacts.require('App');
const VaultFactory = artifacts.require('VaultFactory');
const VaultManagerFactory = artifacts.require('VaultManagerFactory');

module.exports = async (deployer) => {
  deployer.then(async () => {
    const app = await App.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const vaultManagerFactory = await VaultManagerFactory.deployed();

    await app.setContractFactory('Vault', vaultFactory.address);
    await app.setContractFactory('VaultManager', vaultManagerFactory.address);
  });
};
