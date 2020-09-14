const BankVoter = artifacts.require('BankVoter');
const Portfolio = artifacts.require('Portfolio');

module.exports = (deployer) =>
  deployer.then(async () => {
    const bankVoter = await BankVoter.deployed();
    const portfolioAddress = (await Portfolio.deployed()).address;

    await bankVoter.setState(portfolioAddress);
  });
