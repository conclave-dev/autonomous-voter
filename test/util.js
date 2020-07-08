const { newKit } = require('@celo/contractkit');
const contract = require('@truffle/contract');
const BigNumber = require('bignumber.js');
const { registryContractAddress } = require('../config');

const contractBuildFiles = [
  require('../build/contracts/App.json'),
  require('../build/contracts/Archive.json'),
  require('../build/contracts/Vault.json'),
  require('../build/contracts/VaultFactory.json'),
  require('../build/contracts/VoteManager.json'),
  require('../build/contracts/ManagerFactory.json'),
  require('../build/contracts/ManagerFactory.json'),
  require('../build/contracts/ProxyAdmin.json')
];

const getTruffleContracts = (rpcAPI, primaryAccount) =>
  contractBuildFiles.reduce((contracts, { contractName, abi, networks }) => {
    const truffleContract = contract({ contractName, abi, networks });

    truffleContract.setProvider(rpcAPI);

    truffleContract.defaults({
      from: primaryAccount,
      gas: 20000000,
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
    managerCommission: new BigNumber('10'),
    minimumBalanceRequirement: new BigNumber('1e10'),
    registryContractAddress,
    zeroAddress: '0x0000000000000000000000000000000000000000',
    app: await contracts.App.deployed(),
    archive: await contracts.Archive.deployed(),
    vault: await contracts.Vault.deployed(),
    vaultFactory: await contracts.VaultFactory.deployed(),
    managerFactory: await contracts.ManagerFactory.deployed()
  };
};

module.exports = {
  getTruffleContracts,
  setUpGlobalTestVariables
};
