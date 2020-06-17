const { assert } = require('chai').use(require('chai-as-promised'));
const { newKit } = require('@celo/contractkit');
const contract = require('@truffle/contract');
const BigNumber = require('bignumber.js');
const {
  primarySenderAddress,
  alfajoresRpcAPI,
  defaultGas,
  defaultGasPrice,
  registryContractAddress
} = require('../config');

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

  this.rewardSharePercentage = new BigNumber('10');
  this.minimumManageableBalanceRequirement = new BigNumber('1e16');

  this.vaultFactory.createInstance(registryContractAddress, {
    value: new BigNumber('1e17')
  });
  this.vaultManagerFactory.createInstance(this.rewardSharePercentage, this.minimumManageableBalanceRequirement);

  const vault = (await this.archive.getVaultsByOwner(primarySenderAddress)).pop();
  const vaultManager = (await this.archive.getVaultManagersByOwner(primarySenderAddress)).pop();

  this.vaultInstance = await contracts.Vault.at(vault);
  this.proxyAdmin = await contracts.ProxyAdmin.at(await this.vaultInstance.proxyAdmin());
  this.vaultManagerInstance = await contracts.VaultManager.at(vaultManager);
});

module.exports = {
  assert,
  contracts,
  kit: newKit(alfajoresRpcAPI)
};
