const { deployContract } = require('./util');

module.exports = (deployer, networkName, accounts) =>
  deployer.then(async () => {
    await deployContract('VaultFactory', networkName, accounts[0]);
  });
