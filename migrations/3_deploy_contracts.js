const { deployContracts, contractHasUpdates } = require('./util');

const App = artifacts.require('App');
const ImplementationDirectory = artifacts.require('ImplementationDirectory');
const Package = artifacts.require('Package');
const Vault = artifacts.require('Vault');
const VaultFactory = artifacts.require('VaultFactory');
const Bank = artifacts.require('Bank');
const Portfolio = artifacts.require('Portfolio');
const ElectionDataProvider = artifacts.require('ElectionDataProvider');
const BankVoter = artifacts.require('BankVoter');

const contracts = [
  ImplementationDirectory,
  Package,
  Vault,
  VaultFactory,
  Bank,
  Portfolio,
  ElectionDataProvider,
  BankVoter
];

module.exports = async (deployer, network) => {
  // Handle `App` deployment separately since there seems to be a bug for contracts with defined but empty constructor
  // when calling Truffle's deployer while including options (one of which is `overwrite`)
  // so we would check externally and omit the usage of `overwrite` for its deployment
  if (contractHasUpdates(deployer, network, App)) {
    await deployer.deploy(App);
  }

  // Handle the rest of the contracts
  await deployContracts(deployer, network, contracts);

  // Force deployment of factories if Portfolio was updated
  const portfolioUpdated = await contractHasUpdates(deployer, network, Portfolio);

  if (portfolioUpdated) {
    // These contracts must be re-deployed if Portfolio changes (which is always, atm) as they set the Portfolio address
    // when initializing. TODO: Replace initialize with setter fns to update instead of re-deploying
    await deployer.deploy(VaultFactory);
  }
};
