const Promise = require('bluebird');

const Migrations = artifacts.require('Migrations');
const MockRegistry = artifacts.require('MockRegistry');
const MockElection = artifacts.require('MockElection');
const MockAccounts = artifacts.require('MockAccounts');
const MockLockedGold = artifacts.require('MockLockedGold');
const MockVault = artifacts.require('MockVault');
const VaultFactory = artifacts.require('VaultFactory');
const App = artifacts.require('App');

const { compareDeployedBytecodes } = require('./util');

const mockContracts = [MockRegistry, MockElection, MockAccounts, MockLockedGold, MockVault];

module.exports = async (deployer) => {
  await deployer.deploy(Migrations, { overwrite: false });

  await Promise.each(mockContracts, async (contract) => {
    let hasChanged = false;

    try {
      const { address } = await contract.deployed();
      hasChanged = !(await compareDeployedBytecodes(deployer, address, contract.deployedBytecode));
    } catch (err) {
      console.error(err);
    }

    await deployer.deploy(contract, { overwrite: hasChanged });
  });

  const mockRegistry = await MockRegistry.deployed();
  const mockElection = await MockElection.deployed();
  const mockAccounts = await MockAccounts.deployed();
  const mockLockedGold = await MockLockedGold.deployed();
  const mockVault = await MockVault.deployed();
  const vaultFactory = await VaultFactory.deployed();
  const app = await App.deployed();
  const hasMockVault =
    (await app.contractImplementations('MockVault')) === mockVault.address &&
    (await app.contractFactory('MockVault')) === vaultFactory.address;

  if (!hasMockVault) {
    await app.setContractImplementation('MockVault', mockVault.address);
    await app.setContractFactory('MockVault', vaultFactory.address);
  }

  if ((await mockRegistry.election()) !== mockElection.address) {
    await mockRegistry.setElection(mockElection.address);
  }

  if ((await mockRegistry.accounts()) !== mockAccounts.address) {
    await mockRegistry.setAccounts(mockAccounts.address);
  }

  if ((await mockRegistry.lockedGold()) !== mockLockedGold.address) {
    await mockRegistry.setLockedGold(mockLockedGold.address);
  }
};
