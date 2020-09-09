const { newKit } = require('@celo/contractkit');
const contract = require('@truffle/contract');
const BigNumber = require('bignumber.js');
const {
  registryContractAddress,
  packageName,
  tokenDecimal,
  cycleBlockDuration,
  rewardExpiration
} = require('../config');

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
  require('../build/contracts/Portfolio.json'),
  require('../build/contracts/RewardManager.json'),
  require('../build/contracts/MockBank.json'),
  require('../build/contracts/MockRewardManager.json')
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
  const kit = newKit(rpcAPI);

  return {
    contracts,
    kit,
    packageName,
    tokenAmountMultiplier: new BigNumber(10 ** tokenDecimal),
    managerCommission: new BigNumber('10'),
    minimumBalanceRequirement: new BigNumber('1e10'),
    zeroAddress: '0x0000000000000000000000000000000000000000',
    genesisBlockNumber: (await kit.web3.eth.getBlockNumber()) + 1,
    app: await contracts.App.deployed(),
    archive: await contracts.Archive.deployed(),
    vault: await contracts.Vault.deployed(),
    vaultFactory: await contracts.VaultFactory.deployed(),
    managerFactory: await contracts.ManagerFactory.deployed(),
    bank: await contracts.Bank.deployed(),
    portfolio: await contracts.Portfolio.deployed(),
    rewardManager: await contracts.RewardManager.deployed(),
    mockBank: await contracts.MockBank.deployed(),
    mockRewardManager: await contracts.MockRewardManager.deployed()
  };
};

const setUpGlobalTestContracts = async ({
  archive,
  portfolio,
  contracts,
  primarySender,
  secondarySender,
  thirdSender,
  vaultFactory,
  managerFactory,
  managerCommission,
  minimumBalanceRequirement,
  genesisBlockNumber,
  mockBank,
  mockRewardManager
}) => {
  const getVaults = (account) => archive.getVaultsByOwner(account);
  const getManagers = () => archive.getManagersByOwner(primarySender);
  const createVaultInstance = (account) =>
    vaultFactory.createInstance(packageName, 'Vault', registryContractAddress, {
      value: new BigNumber('1e17'),
      from: account
    });
  const createManagerInstance = () =>
    managerFactory.createInstance(packageName, 'VoteManager', managerCommission, minimumBalanceRequirement);

  if (!(await getVaults(primarySender)).length) {
    await createVaultInstance(primarySender);
  }

  if (!(await getManagers()).length) {
    await createManagerInstance();
  }

  // Create new instances
  await createVaultInstance(primarySender);
  await createVaultInstance(secondarySender);
  await createVaultInstance(thirdSender);
  await createManagerInstance();

  const primaryVaults = await getVaults(primarySender);
  const secondaryVaults = await getVaults(secondarySender);
  const thirdVaults = await getVaults(thirdSender);
  const managers = await getManagers();
  const vaultInstance = await contracts.Vault.at(primaryVaults.pop());
  const secondaryVaultInstance = await contracts.Vault.at(secondaryVaults.pop());
  const thirdVaultInstance = await contracts.Vault.at(thirdVaults.pop());

  await portfolio.setCycleParameters(genesisBlockNumber, cycleBlockDuration);

  await mockBank.reset();
  await mockRewardManager.reset();
  await mockRewardManager.setRewardExpiration(rewardExpiration);

  // Maintain state and used for voting tests
  return {
    persistentVaultInstance: await contracts.Vault.at(primaryVaults[0]),
    persistentVoteManagerInstance: await contracts.VoteManager.at(managers[0]),
    vaultInstance,
    secondaryVaultInstance,
    thirdVaultInstance,
    managerInstance: await contracts.VoteManager.at(managers.pop()),
    proxyAdmin: await contracts.ProxyAdmin.at(await vaultInstance.proxyAdmin())
  };
};

module.exports = {
  getTruffleContracts,
  setUpGlobalTestVariables,
  setUpGlobalTestContracts
};
