const Bank = artifacts.require('Bank');
const { seedFreezeDuration } = require('../config');

module.exports = (deployer) =>
  deployer.then(async () => {
    const bank = await Bank.deployed();

    await bank.setSeedFreezeDuration(seedFreezeDuration);
  });
