const { deployContract } = require('../util/openzeppelin');

module.exports = (deployer, networkName, accounts) =>
  deployer
    .then(async () => {
      await deployContract('Archive', networkName, accounts[0]);
    })
    .then(async () => {
      const archive = await artifacts.require('Archive').deployed();

      if (await archive.owner()) {
        return;
      }

      await archive.initialize(accounts[0]);
    });
