const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const StrategyFactory = artifacts.require('StrategyFactory');

module.exports = async (deployer) => {
  deployer.then(async () => {
    const archive = await Archive.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const strategyFactory = await StrategyFactory.deployed();

    await archive.setVaultFactory(vaultFactory.address);
    await archive.setStrategyFactory(strategyFactory.address);
  });
};
