const { deployContract } = require('./util');

module.exports = (deployer, networkName, accounts) =>
  deployer.then(async () => {
    await deployContract('Vault', networkName, accounts[0]);
  });
