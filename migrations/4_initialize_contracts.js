const { newKit } = require('@celo/contractkit');
const Promise = require('bluebird');
const { localRpcAPI, alfajoresRpcAPI, tokenName, tokenSymbol, tokenDecimal, seedFreezeDuration } = require('../config');

const App = artifacts.require('App');
const VaultFactory = artifacts.require('VaultFactory');
const Bank = artifacts.require('Bank');
const Portfolio = artifacts.require('Portfolio');
const ElectionDataProvider = artifacts.require('ElectionDataProvider');

module.exports = (deployer, network) =>
  deployer.then(async () => {
    const kit = newKit(network === 'local' ? localRpcAPI : alfajoresRpcAPI);
    const registryContractAddress = kit.registry.cache.get('Registry');
    const electionContractAddress = (await kit.contracts.getElection()).address;
    const app = await App.deployed();
    const bank = await Bank.deployed();
    const portfolio = await Portfolio.deployed();
    const electionDataProvider = await ElectionDataProvider.deployed();
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
        contract: 'ElectionDataProvider',
        fn: async () => await electionDataProvider.initialize(electionContractAddress)
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
