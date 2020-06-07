const App = artifacts.require('App');
const Vault = artifacts.require('Vault');
const Strategy = artifacts.require('Strategy');

module.exports = async (deployer) => {
  await deployer.deploy(App, { overwrite: false });

  // const app = await App.deployed();
  const { address: vaultAddress } = await Vault.deployed();
  const { address: strategyAddress } = await Strategy.deployed();

  // await app.initialize();
  await app.setImplementation('Vault', vaultAddress);
  await app.setImplementation('Strategy', strategyAddress);
};
