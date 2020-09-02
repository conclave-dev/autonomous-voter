const Promise = require('bluebird');
const { registryContractAddress, tokenName, tokenSymbol, tokenDecimal, seedFreezeDuration } = require('../config');

const App = artifacts.require('App');
const VaultFactory = artifacts.require('VaultFactory');
const Bank = artifacts.require('Bank');
const Portfolio = artifacts.require('Portfolio');

module.exports = (deployer) =>
  deployer.then(async () => {
    const app = await App.deployed();
    const bank = await Bank.deployed();
    const portfolio = await Portfolio.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const contractInitializers = [
      {
        contract: 'Bank',
        fn: async () =>
          await bank.initializeBank(
            tokenName,
            tokenSymbol,
            tokenDecimal,
            [],
            [],
            seedFreezeDuration,
            registryContractAddress
          )
      },
      {
        contract: 'Portfolio',
        fn: async () => await portfolio.initialize(registryContractAddress)
      },
      {
        contract: 'VaultFactory',
        fn: async () => await vaultFactory.initialize(app.address, portfolio.address)
      }
    ];

    await Promise.each(contractInitializers, async ({ contract, fn }) => {
      try {
        await fn();
      } catch (err) {
        console.error(`Error calling ${contract} initializer: ${err}`);
      }
    });
  });
