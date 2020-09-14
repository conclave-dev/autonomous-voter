const BankVoter = artifacts.require('BankVoter');
const ElectionDataProvider = artifacts.require('ElectionDataProvider');
const Portfolio = artifacts.require('Portfolio');

module.exports = (deployer) =>
  deployer.then(async () => {
    const bankVoter = await BankVoter.deployed();
    const portfolioAddress = (await Portfolio.deployed()).address;
    const electionDataProviderAddress = (await ElectionDataProvider.deployed()).address;

    await bankVoter.setState(electionDataProviderAddress, portfolioAddress);
  });
