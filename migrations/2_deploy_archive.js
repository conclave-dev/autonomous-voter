const { deployContract } = require('./util');

module.exports = (deployer, networkName, accounts) =>
  deployer.then(async () => {
    await deployContract('Archive', networkName, accounts[0]);
  });
