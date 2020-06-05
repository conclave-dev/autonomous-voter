const { deployContract } = require('../util/openzeppelin');

module.exports = (deployer, network, accounts) =>
  deployer.then(async () => {
    await deployContract('VaultFactory', network, accounts[0]);
  });
