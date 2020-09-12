const Portfolio = artifacts.require('Portfolio');
const Bank = artifacts.require('Bank');
const ElectionDataProvider = artifacts.require('ElectionDataProvider');
const VaultFactory = artifacts.require('VaultFactory');
const { minimumUpvoterBalance, maximumProposalGroups } = require('../config');

module.exports = (deployer) =>
  deployer.then(async () => {
    const portfolio = await Portfolio.deployed();
    const bankAddress = (await Bank.deployed()).address;
    const electionDataProviderAddress = (await ElectionDataProvider.deployed()).address;
    const vaultFactoryAddress = (await VaultFactory.deployed()).address;

    await portfolio.setContracts(bankAddress, electionDataProviderAddress, vaultFactoryAddress);
    await portfolio.setParameters(minimumUpvoterBalance, maximumProposalGroups);
  });
