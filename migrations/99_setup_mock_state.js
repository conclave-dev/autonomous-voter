const MockBank = artifacts.require('MockBank');
const MockRewardManager = artifacts.require('MockRewardManager');
const { seedFreezeDuration } = require('../config');

module.exports = (deployer) =>
  deployer.then(async () => {
    const mockBank = await MockBank.deployed();
    const mockRewardManager = await MockRewardManager.deployed();

    await mockBank.setRewardManager(mockRewardManager.address);
    await mockBank.setSeedFreezeDuration(seedFreezeDuration);
  });
