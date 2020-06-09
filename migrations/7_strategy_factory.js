const StrategyFactory = artifacts.require('StrategyFactory');
const App = artifacts.require('App');
const Archive = artifacts.require('Archive');

module.exports = async (deployer) => {
  await deployer.deploy(StrategyFactory);

  const strategyFactory = await StrategyFactory.deployed();
  const { address: appAddress } = await App.deployed();
  const { address: archiveAddress } = await Archive.deployed();

  await strategyFactory.initialize(appAddress, archiveAddress);
};
