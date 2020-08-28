const { newKit } = require('@celo/contractkit');
const contract = require('@truffle/contract');
const BigNumber = require('bignumber.js');
const { registryContractAddress, packageName, tokenDecimal } = require('../config');

const contractBuildFiles = [
  require('../build/contracts/App.json'),
  require('../build/contracts/Archive.json'),
  require('../build/contracts/Vault.json'),
  require('../build/contracts/VaultFactory.json'),
  require('../build/contracts/VoteManager.json'),
  require('../build/contracts/ManagerFactory.json'),
  require('../build/contracts/ManagerFactory.json'),
  require('../build/contracts/ProxyAdmin.json'),
  require('../build/contracts/Bank.json'),
  require('../build/contracts/Portfolio.json')
];

const getTruffleContracts = (rpcAPI, primaryAccount) =>
  contractBuildFiles.reduce((contracts, { contractName, abi, networks }) => {
    const truffleContract = contract({ contractName, abi, networks });

    truffleContract.setProvider(rpcAPI);

    truffleContract.defaults({
      from: primaryAccount,
      gas: 10000000,
      gasPrice: 100000000000
    });

    return {
      ...contracts,
      [contractName]: truffleContract
    };
  }, {});

const setUpGlobalTestVariables = async (rpcAPI, primaryAccount) => {
  const contracts = getTruffleContracts(rpcAPI, primaryAccount);

  return {
    contracts,
    kit: newKit(rpcAPI),
    packageName,
    tokenAmountMultiplier: new BigNumber(10 ** tokenDecimal),
    managerCommission: new BigNumber('10'),
    minimumBalanceRequirement: new BigNumber('1e10'),
    zeroAddress: '0x0000000000000000000000000000000000000000',
    app: await contracts.App.deployed(),
    archive: await contracts.Archive.deployed(),
    vault: await contracts.Vault.deployed(),
    vaultFactory: await contracts.VaultFactory.deployed(),
    managerFactory: await contracts.ManagerFactory.deployed(),
    bank: await contracts.Bank.deployed(),
    portfolio: await contracts.Portfolio.deployed()
  };
};

const setUpGlobalTestContracts = async ({
  archive,
  contracts,
  primarySender,
  secondarySender,
  vaultFactory,
  managerFactory,
  managerCommission,
  minimumBalanceRequirement
}) => {
  const getPrimaryVaults = () => archive.getVaultsByOwner(primarySender);
  const getSecondaryVaults = () => archive.getVaultsByOwner(secondarySender);
  const getManagers = () => archive.getManagersByOwner(primarySender);
  const createVaultInstance = () =>
    vaultFactory.createInstance(packageName, 'Vault', registryContractAddress, {
      value: new BigNumber('1e17')
    });
  const createSecondaryVaultInstance = () =>
    vaultFactory.createInstance(packageName, 'Vault', registryContractAddress, {
      value: new BigNumber('1e17'),
      from: secondarySender
    });
  const createManagerInstance = () =>
    managerFactory.createInstance(packageName, 'VoteManager', managerCommission, minimumBalanceRequirement);

  if (!(await getPrimaryVaults()).length) {
    await createVaultInstance();
  }

  if (!(await getManagers()).length) {
    await createManagerInstance();
  }

  // Create new instances
  await createVaultInstance();
  await createSecondaryVaultInstance();
  await createManagerInstance();

  const primaryVaults = await getPrimaryVaults();
  const secondaryVaults = await getSecondaryVaults();
  const managers = await getManagers();
  const vaultInstance = await contracts.Vault.at(primaryVaults.pop());
  const secondaryVaultInstance = await contracts.Vault.at(secondaryVaults.pop());

  // Maintain state and used for voting tests
  return {
    persistentVaultInstance: await contracts.Vault.at(primaryVaults[0]),
    persistentVoteManagerInstance: await contracts.VoteManager.at(managers[0]),
    vaultInstance,
    secondaryVaultInstance,
    managerInstance: await contracts.VoteManager.at(managers.pop()),
    proxyAdmin: await contracts.ProxyAdmin.at(await vaultInstance.proxyAdmin())
  };
};

module.exports = {
  getTruffleContracts,
  setUpGlobalTestVariables,
  setUpGlobalTestContracts
};
