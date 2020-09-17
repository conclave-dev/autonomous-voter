const Rewards = artifacts.require('Rewards');
const Portfolio = artifacts.require('Portfolio');

module.exports = (deployer) =>
  deployer.then(async () => {
    const rewards = await Rewards.deployed();
    const portfolioAddress = (await Portfolio.deployed()).address;

    await rewards.setState(portfolioAddress);
  });
