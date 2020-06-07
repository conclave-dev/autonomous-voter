const App = artifacts.require('App');
const Vault = artifacts.require('Vault');

module.exports = async (deployer) => {
  await deployer.deploy(App);

  const app = await App.deployed();
  const { address: vaultAddress } = await Vault.deployed();

  await app.initialize(vaultAddress);
};
