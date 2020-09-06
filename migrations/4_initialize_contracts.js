const Promise = require('bluebird');
const {
  registryContractAddress,
  tokenName,
  tokenSymbol,
  tokenDecimal,
  seedFreezeDuration,
  rewardExpiration,
  holderRewardPercentage
} = require('../config');

const App = artifacts.require('App');
const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const ManagerFactory = artifacts.require('ManagerFactory');
const Bank = artifacts.require('Bank');
const Portfolio = artifacts.require('Portfolio');
const RewardManager = artifacts.require('RewardManager');

const MockBank = artifacts.require('MockBank');

module.exports = (deployer) =>
  deployer.then(async () => {
    const app = await App.deployed();
    const archive = await Archive.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const managerFactory = await ManagerFactory.deployed();
    const bank = await Bank.deployed();
    const portfolio = await Portfolio.deployed();
    const rewardManager = await RewardManager.deployed();
    const mockBank = await MockBank.deployed();
    const contractInitializers = [
      { contract: 'Archive', fn: async () => await archive.initialize(registryContractAddress) },
      {
        contract: 'VaultFactory',
        fn: async () => await vaultFactory.initialize(app.address, archive.address)
      },
      {
        contract: 'ManagerFactory',
        fn: async () => await managerFactory.initialize(app.address, archive.address)
      },
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
        contract: 'RewardManager',
        fn: async () => await rewardManager.initialize(bank.address, rewardExpiration, holderRewardPercentage)
      },
      {
        contract: 'MockBank',
        fn: async () =>
          await mockBank.initializeBank(
            tokenName,
            tokenSymbol,
            tokenDecimal,
            [],
            [],
            seedFreezeDuration,
            registryContractAddress
          )
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
