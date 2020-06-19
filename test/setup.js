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
  require('../build/contracts/ProxyAdmin.json'),
  require('../build/contracts/MockVault.json'),
  require('../build/contracts/MockElection.json')
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
  this.mockVault = await contracts.MockVault.deployed();
  this.mockElection = await contracts.MockElection.deployed();

  // Reusable testing variables
  this.rewardSharePercentage = new BigNumber('10');
  this.minimumManageableBalanceRequirement = new BigNumber('1e16');
  this.zeroAddress = '0x0000000000000000000000000000000000000000';

  const getVaults = () => this.archive.getVaultsByOwner(primarySenderAddress);
  const getVaultManagers = () => this.archive.getVaultManagersByOwner(primarySenderAddress);
  const createVaultInstance = () =>
    this.vaultFactory.createInstance(registryContractAddress, {
      value: new BigNumber('1e17')
    });
  const createVaultManagerInstance = () =>
    this.vaultManagerFactory.createInstance(this.rewardSharePercentage, this.minimumManageableBalanceRequirement);

  // Conditionally create persistent test instances if they don't yet exist
  if (!(await getVaults()).length) {
    await createVaultInstance();
  }

  if (!(await getVaultManagers()).length) {
    await createVaultManagerInstance();
  }

  // Always create fresh test instances
  await createVaultInstance();
  await createVaultManagerInstance();

  const vaults = await getVaults();
  const vaultManagers = await getVaultManagers();

  // Maintain state and used for voting tests
  this.persistentVaultInstance = await contracts.Vault.at(vaults[0]);
  this.persistentVotingManagerInstance = await contracts.VotingVaultManager.at(vaultManagers[0]);
  this.vaultInstance = await contracts.Vault.at(vaults.pop());
  this.vaultManagerInstance = await contracts.VotingVaultManager.at(vaultManagers.pop());
  this.proxyAdmin = await contracts.ProxyAdmin.at(await this.vaultInstance.proxyAdmin());
});

module.exports = {
  assert,
  contracts,
  kit: newKit(alfajoresRpcAPI)
};
