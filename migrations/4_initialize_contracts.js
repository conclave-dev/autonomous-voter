const Promise = require('bluebird');
const { default: BigNumber } = require('bignumber.js');
const { registryContractAddress, tokenName, tokenSymbol, tokenSupply, tokenDecimal } = require('../config');

const App = artifacts.require('App');
const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const ManagerFactory = artifacts.require('ManagerFactory');
const Bank = artifacts.require('Bank');

module.exports = (deployer) =>
  deployer.then(async () => {
    const app = await App.deployed();
    const archive = await Archive.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const managerFactory = await ManagerFactory.deployed();
    const bank = await Bank.deployed();
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
        fn: async () => await bank.initialize(tokenName, tokenSymbol, tokenDecimal, new BigNumber(tokenSupply), [])
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
