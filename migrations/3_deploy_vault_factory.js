const VaultFactory = artifacts.require('VaultFactory');
const { deployContract } = require('./util');

module.exports = async (deployer, networkName, accounts) => {
  await deployer.deploy(VaultFactory);

  await deployer.then(async () => {
    await deployContract('VaultFactory', networkName, accounts[0]);
  });
};
