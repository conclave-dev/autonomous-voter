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
  require('../build/contracts/VotingVaultManager.json'),
  require('../build/contracts/VotingVaultManagerFactory.json'),
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
  this.vaultFactory = await contracts.VaultFactory.deployed();
  this.vaultManagerFactory = await contracts.VotingVaultManagerFactory.deployed();
  this.rewardSharePercentage = new BigNumber('10');
  this.minimumManageableBalanceRequirement = new BigNumber('1e16');
  this.zeroAddress = '0x0000000000000000000000000000000000000000';

  await this.vaultFactory.createInstance(registryContractAddress, {
    value: new BigNumber('1e17')
  });
  await this.vaultManagerFactory.createInstance(this.rewardSharePercentage, this.minimumManageableBalanceRequirement);

  const vaults = await this.archive.getVaultsByOwner(primarySenderAddress);
  const votingVaultManagers = await this.archive.getVaultManagersByOwner(primarySenderAddress);

  this.vaultInstance = await contracts.Vault.at(vaults.pop());
  this.proxyAdmin = await contracts.ProxyAdmin.at(await this.vaultInstance.proxyAdmin());
  this.vaultManagerInstance = await contracts.VotingVaultManager.at(votingVaultManagers.pop());
  this.persistentVaultInstance = await contracts.Vault.at(vaults[0]);
  this.persistentVaultManagerInstance = await contracts.VotingVaultManager.at(votingVaultManagers[0]);
});

module.exports = {
  assert,
  contracts,
  kit: newKit(alfajoresRpcAPI)
};
