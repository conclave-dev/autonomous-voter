const Promise = require('bluebird');
const { compareDeployedBytecodes } = require('./util');

const App = artifacts.require('App');
const Vault = artifacts.require('Vault');
const VotingVaultManager = artifacts.require('VotingVaultManager');
const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const VotingVaultManagerFactory = artifacts.require('VotingVaultManagerFactory');
const MockVault = artifacts.require('MockVault');
const MockLockedGold = artifacts.require('MockLockedGold');
const MockVaultFactory = artifacts.require('MockVaultFactory');
const MockArchive = artifacts.require('MockArchive');

const contracts = [
  App,
  Vault,
  Archive,
  VaultFactory,
  VotingVaultManager,
  VotingVaultManagerFactory,
  MockVault,
  MockLockedGold,
  MockVaultFactory,
  MockArchive
];

module.exports = (deployer) => {
  deployer.then(async () => {
    // Iterate over contracts and deploy the undeployed
    await Promise.each(contracts, async (contract) => {
      let hasChanged = false;

      try {
        // Update contracts if the deployed contract runtime bytecodes differ from Truffle's
        // NOTE: A few contracts (such as Archive) will always update. Need to come up with better solution
        const { address } = await contract.deployed();
        hasChanged = !(await compareDeployedBytecodes(deployer, address, contract.deployedBytecode));
      } catch (err) {
        console.error(err);
      }

      await deployer.deploy(contract, { overwrite: hasChanged });
    });

    const archive = await Archive.deployed();
    const archiveChanged = !(await compareDeployedBytecodes(deployer, archive.address, App.deployedBytecode));

    if (archiveChanged) {
      // These contracts must be re-deployed if Archive changes (which is always, atm) as they set the Archive address
      // when initializing. TODO: Replace initialize with setter fns to update instead of re-deploying
      await deployer.deploy(VaultFactory);
      await deployer.deploy(VotingVaultManagerFactory);
    }

    const mockArchive = await MockArchive.deployed();
    const mockArchiveChanged = !(await compareDeployedBytecodes(deployer, mockArchive.address, App.deployedBytecode));

    if (mockArchiveChanged) {
      // These contracts must be re-deployed if Archive changes (which is always, atm) as they set the Archive address
      // when initializing. TODO: Replace initialize with setter fns to update instead of re-deploying
      await deployer.deploy(MockVaultFactory);
    }
  });
};
