const { newKit } = require('@celo/contractkit');
const contract = require('@truffle/contract');
const BigNumber = require('bignumber.js');
const { packageName, tokenDecimal } = require('../config');

const contractBuildFiles = [
  require('../build/contracts/App.json'),
  require('../build/contracts/Vault.json'),
  require('../build/contracts/VaultFactory.json'),
  require('../build/contracts/ProxyAdmin.json'),
  require('../build/contracts/Bank.json'),
  require('../build/contracts/Portfolio.json'),
  require('../build/contracts/Rewards.json')
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
    app: await contracts.App.deployed(),
    vault: await contracts.Vault.deployed(),
    vaultFactory: await contracts.VaultFactory.deployed(),
    bank: await contracts.Bank.deployed(),
    portfolio: await contracts.Portfolio.deployed(),
    rewards: await contracts.Rewards.deployed()
  };
};

const setUpGlobalTestContracts = async ({
  kit,
  portfolio,
  contracts,
  primarySender,
  secondarySender,
  thirdSender,
  vaultFactory
}) => {
  const registryContractAddress = kit.registry.cache.get('Registry');
  const getVaultByOwner = (account) => portfolio.vaultsByOwner(account);
  const createVaultInstance = (account) =>
    vaultFactory.createInstance(packageName, 'Vault', registryContractAddress, {
      from: account
    });

  // Create new instances
  await createVaultInstance(primarySender);
  await createVaultInstance(secondarySender);
  await createVaultInstance(thirdSender);

  const primaryVault = await getVaultByOwner(primarySender);
  const secondaryVault = await getVaultByOwner(secondarySender);
  const thirdVault = await getVaultByOwner(thirdSender);
  const vaultInstance = await contracts.Vault.at(primaryVault);
  const secondaryVaultInstance = await contracts.Vault.at(secondaryVault);
  const thirdVaultInstance = await contracts.Vault.at(thirdVault);

  // Maintain state and used for voting tests
  return {
    registryContractAddress,
    vaultInstance,
    secondaryVaultInstance,
    thirdVaultInstance,
    proxyAdmin: await contracts.ProxyAdmin.at(await vaultInstance.proxyAdmin())
  };
};

module.exports = {
  getTruffleContracts,
  setUpGlobalTestVariables,
  setUpGlobalTestContracts
};
