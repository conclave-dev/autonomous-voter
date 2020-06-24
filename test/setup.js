const { assert } = require('chai').use(require('chai-as-promised'));
const { newKit } = require('@celo/contractkit');
const contract = require('@truffle/contract');
const BigNumber = require('bignumber.js');
const {
  primarySenderAddress,
  secondarySenderAddress,
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
  require('../build/contracts/VoteManager.json'),
  require('../build/contracts/ManagerFactory.json'),
  require('../build/contracts/ProxyAdmin.json'),
  require('../build/contracts/MockVault.json'),
  require('../build/contracts/MockLockedGold.json'),
  require('../build/contracts/MockElection.json'),
  require('../build/contracts/MockRegistry.json')
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
  this.managerFactory = await contracts.ManagerFactory.deployed();

  // Reusable testing variables
  this.managerCommission = new BigNumber('10');
  this.minimumManageableBalanceRequirement = new BigNumber('1e16');
  this.zeroAddress = '0x0000000000000000000000000000000000000000';

  const getVaults = () => this.archive.getVaultsByOwner(primarySenderAddress);
  const getManagers = () => this.archive.getManagersByOwner(primarySenderAddress);
  const createVaultInstance = () =>
    this.vaultFactory.createInstance('Vault', registryContractAddress, {
      value: new BigNumber('1e17')
    });
  const createManagerInstance = () =>
    this.managerFactory.createInstance('VoteManager', this.managerCommission, this.minimumManageableBalanceRequirement);

  // Conditionally create persistent test instances if they don't yet exist
  if (!(await getVaults()).length) {
    await createVaultInstance();
  }

  if (!(await getManagers()).length) {
    await createManagerInstance();
  }

  // Always create fresh test instances
  await createVaultInstance();
  await createManagerInstance();

  const vaults = await getVaults();
  const managers = await getManagers();

  // Maintain state and used for voting tests
  this.persistentVaultInstance = await contracts.Vault.at(vaults[0]);
  this.persistentVoteManagerInstance = await contracts.VoteManager.at(managers[0]);
  this.vaultInstance = await contracts.Vault.at(vaults.pop());
  this.managerInstance = await contracts.VoteManager.at(managers.pop());
  this.proxyAdmin = await contracts.ProxyAdmin.at(await this.vaultInstance.proxyAdmin());

  await this.vaultFactory.createInstance('MockVault', (await contracts.MockRegistry.deployed()).address, {
    value: new BigNumber('1e17')
  });

  this.mockVault = await contracts.MockVault.at((await getVaults()).pop());
  this.mockElection = await contracts.MockElection.deployed();
  this.mockLockedGold = await contracts.MockLockedGold.deployed();

  await this.mockElection.initValidatorGroups([primarySenderAddress, secondarySenderAddress]);
});

module.exports = {
  assert,
  contracts,
  kit: newKit(alfajoresRpcAPI)
};
