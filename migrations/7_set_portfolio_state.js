const Portfolio = artifacts.require('Portfolio');
const Bank = artifacts.require('Bank');
const VaultFactory = artifacts.require('VaultFactory');
const { minimumUpvoterBalance, maximumProposalGroups } = require('../config');

module.exports = (deployer) =>
  deployer.then(async () => {
    const portfolio = await Portfolio.deployed();
    const bankAddress = (await Bank.deployed()).address;
    const vaultFactoryAddress = (await VaultFactory.deployed()).address;

    await portfolio.setProtocolContracts(bankAddress, vaultFactoryAddress);
    await portfolio.setProtocolParameters(minimumUpvoterBalance, maximumProposalGroups);
  });
