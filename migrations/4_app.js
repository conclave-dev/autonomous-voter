const App = artifacts.require('App');
const Vault = artifacts.require('Vault');
const Strategy = artifacts.require('Strategy');

module.exports = async (deployer) => {
  await deployer.deploy(App);

  const app = await App.deployed();
  const { address: vaultAddress } = await Vault.deployed();
  const { address: strategyAddress } = await Strategy.deployed();

  await app.initialize();
  await app.setContractImplementation('Vault', vaultAddress);
  await app.setContractImplementation('Strategy', strategyAddress);
};
