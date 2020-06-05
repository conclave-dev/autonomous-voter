const Vault = artifacts.require('Vault');
const { deployContract } = require('./util');

module.exports = async (deployer, networkName, accounts) => {
  await deployer.deploy(Vault);

  await deployer.then(async () => {
    await deployContract('Vault', networkName, accounts[0]);
  });
};
