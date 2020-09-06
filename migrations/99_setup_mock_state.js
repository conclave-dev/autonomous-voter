const MockBank = artifacts.require('MockBank');
const RewardManager = artifacts.require('RewardManager');
const { seedFreezeDuration } = require('../config');

module.exports = (deployer) =>
  deployer.then(async () => {
    const mockBank = await MockBank.deployed();
    const rewardManager = await RewardManager.deployed();

    await mockBank.setRewardManager(rewardManager.address);
    await mockBank.setSeedFreezeDuration(seedFreezeDuration);
  });
