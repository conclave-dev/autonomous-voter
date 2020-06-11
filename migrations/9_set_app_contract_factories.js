const App = artifacts.require('App');
const VaultFactory = artifacts.require('VaultFactory');
const StrategyFactory = artifacts.require('StrategyFactory');

module.exports = async (deployer) => {
  deployer.then(async () => {
    const app = await App.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const strategyFactory = await StrategyFactory.deployed();

    await app.setContractFactory('Vault', vaultFactory.address);
    await app.setContractFactory('Strategy', strategyFactory.address);
  });
};
