const { expect, assert } = require('chai').use(require('chai-as-promised'));
const { newKit } = require('@celo/contractkit');
const contract = require('@truffle/contract');
const { primarySenderAddress, alfajoresRpcAPI, defaultGas, defaultGasPrice } = require('../config');

const contractBuildFiles = [
  require('../build/contracts/App.json'),
  require('../build/contracts/Archive.json'),
  require('../build/contracts/Vault.json'),
  require('../build/contracts/VaultFactory.json'),
  require('../build/contracts/VaultManager.json'),
  require('../build/contracts/VaultManagerFactory.json'),
  require('../build/contracts/ProxyAdmin.json')
];

const getTruffleContracts = () =>
  contractBuildFiles.reduce((contracts, { contractName, abi, networks }) => {
    const truffleContract = contract({ contractName, abi, networks });

    truffleContract.setProvider(alfajoresRpcAPI);

    truffleContract.defaults({
      from: primarySenderAddress,
      gas: defaultGas,
      gasPrice: defaultGasPrice
    });

    return {
      ...contracts,
      [contractName]: truffleContract
    };
  }, {});

const contracts = getTruffleContracts();

before(async function () {
  this.app = await contracts.App.deployed();
  this.archive = await contracts.Archive.deployed();
  this.vault = await contracts.Vault.deployed();
  this.vaultManager = await contracts.VaultManager.deployed();
  this.vaultFactory = await contracts.VaultFactory.deployed();
  this.vaultManagerFactory = await contracts.VaultManagerFactory.deployed();
});

module.exports = {
  expect,
  assert,
  contracts,
  kit: newKit(alfajoresRpcAPI)
};
