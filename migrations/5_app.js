const App = artifacts.require('App');
const Vault = artifacts.require('Vault');
const VaultManager = artifacts.require('VaultManager');

module.exports = async (deployer) => {
  await deployer.deploy(App);

  const app = await App.deployed();
  const { address: vaultAddress } = await Vault.deployed();
  const { address: vaultManagerAddress } = await VaultManager.deployed();

  await app.initialize();
  await app.setContractImplementation('Vault', vaultAddress);
  await app.setContractImplementation('VaultManager', vaultManagerAddress);
};
