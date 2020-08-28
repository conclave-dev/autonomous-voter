const Bank = artifacts.require('Bank');
const Portfolio = artifacts.require('Portfolio');
const { seedFreezeDuration } = require('../config');

module.exports = (deployer) =>
  deployer.then(async () => {
    const bank = await Bank.deployed();
    const portfolio = await Portfolio.deployed();

    await bank.setPortfolio(portfolio.address);
    await bank.setSeedFreezeDuration(seedFreezeDuration);
  });
