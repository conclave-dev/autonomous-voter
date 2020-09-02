const { newKit } = require('@celo/contractkit');
const contract = require('@truffle/contract');
const BigNumber = require('bignumber.js');
const { registryContractAddress, packageName, tokenDecimal, cycleBlockDuration } = require('../config');

const contractBuildFiles = [
  require('../build/contracts/App.json'),
  require('../build/contracts/Vault.json'),
  require('../build/contracts/VaultFactory.json'),
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
    vault: await contracts.Vault.deployed(),
    vaultFactory: await contracts.VaultFactory.deployed(),
    bank: await contracts.Bank.deployed(),
    portfolio: await contracts.Portfolio.deployed()
  };
};

const setUpGlobalTestContracts = async ({
  portfolio,
  contracts,
  primarySender,
  secondarySender,
  thirdSender,
  vaultFactory,
  genesisBlockNumber
}) => {
  const getVaults = (account) => portfolio.getVaultsByOwner(account);
  const createVaultInstance = (account) =>
    vaultFactory.createInstance(packageName, 'Vault', registryContractAddress, {
      value: new BigNumber('1e17'),
      from: account
    });

  if (!(await getVaults(primarySender)).length) {
    await createVaultInstance(primarySender);
  }

  // Create new instances
  await createVaultInstance(primarySender);
  await createVaultInstance(secondarySender);
  await createVaultInstance(thirdSender);

  const primaryVaults = await getVaults(primarySender);
  const secondaryVaults = await getVaults(secondarySender);
  const thirdVaults = await getVaults(thirdSender);
  const vaultInstance = await contracts.Vault.at(primaryVaults.pop());
  const secondaryVaultInstance = await contracts.Vault.at(secondaryVaults.pop());
  const thirdVaultInstance = await contracts.Vault.at(thirdVaults.pop());

  await portfolio.setProtocolParameters(genesisBlockNumber, cycleBlockDuration);

  // Maintain state and used for voting tests
  return {
    vaultInstance,
    secondaryVaultInstance,
    thirdVaultInstance,
    persistentVaultInstance: await contracts.Vault.at(primaryVaults[0]),
    proxyAdmin: await contracts.ProxyAdmin.at(await vaultInstance.proxyAdmin())
  };
};

module.exports = {
  getTruffleContracts,
  setUpGlobalTestVariables,
  setUpGlobalTestContracts
};
