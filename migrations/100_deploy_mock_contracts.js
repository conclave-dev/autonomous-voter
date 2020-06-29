const { newKit } = require('@celo/contractkit');
const { deployContracts } = require('./util');

const LinkedList = artifacts.require('LinkedList');
const AddressLinkedList = artifacts.require('AddressLinkedList');
const MockRegistry = artifacts.require('MockRegistry');
const MockElection = artifacts.require('MockElection');
const MockVault = artifacts.require('MockVault');
const VaultFactory = artifacts.require('VaultFactory');
const App = artifacts.require('App');

const mockContracts = [MockRegistry, MockElection, MockVault];

module.exports = async (deployer, network) => {
  await deployer.link(LinkedList, MockVault);
  await deployer.link(AddressLinkedList, MockElection);

  await deployContracts(deployer, network, mockContracts);

  const mockRegistry = await MockRegistry.deployed();
  const mockElection = await MockElection.deployed();
  const mockVault = await MockVault.deployed();
  const vaultFactory = await VaultFactory.deployed();
  const app = await App.deployed();
  const hasMockVault =
    (await app.contractImplementations('MockVault')) === mockVault.address &&
    (await app.contractFactories('MockVault')) === vaultFactory.address;

  if (!hasMockVault) {
    await app.setContractImplementation('MockVault', mockVault.address);
    await app.setContractFactory('MockVault', vaultFactory.address);
  }

  const kit = newKit(deployer.provider.host);
  const accounts = await kit.contracts.getAccounts();
  const lockedGold = await kit.contracts.getLockedGold();

  if ((await mockRegistry.election()) !== mockElection.address) {
    await mockRegistry.setElection(mockElection.address);
  }

  if ((await mockRegistry.accounts()) !== accounts.address) {
    await mockRegistry.setAccounts(accounts.address);
  }

  if ((await mockRegistry.lockedGold()) !== lockedGold.address) {
    await mockRegistry.setLockedGold(lockedGold.address);
  }
};
