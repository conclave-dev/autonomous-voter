const { assert } = require('chai').use(require('chai-as-promised'));
const { newKit } = require('@celo/contractkit');
const contract = require('@truffle/contract');
const BigNumber = require('bignumber.js');
const {
  primarySenderAddress,
  secondarySenderAddress,
  alfajoresRpcAPI,
  localRpcAPI,
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
  require('../build/contracts/ProxyAdmin.json')
];

const getTruffleContracts = (primarySender, rpcAPI) =>
  contractBuildFiles.reduce((contracts, { contractName, abi, networks }) => {
    const truffleContract = contract({ contractName, abi, networks });

    truffleContract.setProvider(rpcAPI);

    truffleContract.defaults({
      from: primarySender,
      gas: defaultGas,
      gasPrice: defaultGasPrice
    });

    return {
      ...contracts,
      [contractName]: truffleContract
    };
  }, {});

let contracts;

before(async function () {
  try {
    this.kit = newKit(localRpcAPI);

    const localAccounts = await this.kit.web3.eth.getAccounts();

    this.primarySender = localAccounts[0];
    this.secondarySender = localAccounts[1];

    contracts = getTruffleContracts(this.primarySender, localRpcAPI);
  } catch (err) {
    console.log('Local accounts unavailable', err);

    this.kit = newKit(alfajoresRpcAPI);
    this.primarySender = primarySenderAddress;
    this.secondarySender = secondarySenderAddress;

    contracts = getTruffleContracts(this.primarySender, alfajoresRpcAPI);
  }

  this.app = await contracts.App.deployed();
  this.archive = await contracts.Archive.deployed();
  this.vault = await contracts.Vault.deployed();
  this.vaultFactory = await contracts.VaultFactory.deployed();
  this.managerFactory = await contracts.ManagerFactory.deployed();

  // Reusable testing variables
  this.managerCommission = new BigNumber('10');
  this.minimumBalanceRequirement = new BigNumber('1e10');
  this.zeroAddress = '0x0000000000000000000000000000000000000000';

  const getVaults = () => this.archive.getVaultsByOwner(this.primarySender);
  const getManagers = () => this.archive.getManagersByOwner(this.primarySender);
  const createVaultInstance = () =>
    this.vaultFactory.createInstance('Vault', registryContractAddress, {
      value: new BigNumber('1e17')
    });
  const createManagerInstance = () =>
    this.managerFactory.createInstance('VoteManager', this.managerCommission, this.minimumBalanceRequirement);

  // Conditionally create persistent test instances if they don't yet exist
  if (!(await getVaults()).length) {
    await createVaultInstance();
  }

  if (!(await getManagers()).length) {
    await createManagerInstance();
  }

  // Always create fresh test instances
  await createManagerInstance();

  const vaults = await getVaults();
  const managers = await getManagers();

  // Maintain state and used for voting tests
  this.persistentVaultInstance = await contracts.Vault.at(vaults[0]);
  this.persistentVoteManagerInstance = await contracts.VoteManager.at(managers[0]);
  this.vaultInstance = await contracts.Vault.at(vaults.pop());
  this.managerInstance = await contracts.VoteManager.at(managers.pop());
  this.proxyAdmin = await contracts.ProxyAdmin.at(await this.vaultInstance.proxyAdmin());
});

module.exports = {
  assert,
  contracts
};
