const Bank = artifacts.require('Bank');
const Portfolio = artifacts.require('Portfolio');
const { groupLimit, proposerMinimum } = require('../config');

module.exports = (deployer) =>
  deployer.then(async () => {
    const portfolio = await Portfolio.deployed();
    const bank = await Bank.deployed();

    // NOTE: Must set the Cycle module parameters separately
    await portfolio.setProposalsParameters(bank.address, groupLimit, proposerMinimum);
  });
