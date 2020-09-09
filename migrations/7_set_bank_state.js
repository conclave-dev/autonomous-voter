const Bank = artifacts.require('Bank');
const Portfolio = artifacts.require('Portfolio');
const RewardManager = artifacts.require('RewardManager');
const { seedFreezeDuration } = require('../config');

module.exports = (deployer) =>
  deployer.then(async () => {
    const bank = await Bank.deployed();
    const portfolio = await Portfolio.deployed();
    const rewardManager = await RewardManager.deployed();

    await bank.setPortfolio(portfolio.address);
    await bank.setRewardManager(rewardManager.address);
    await bank.setSeedFreezeDuration(seedFreezeDuration);
  });
