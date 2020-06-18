const Promise = require('bluebird');
const BigNumber = require('bignumber.js');

const Migrations = artifacts.require('Migrations');
const LinkedList = artifacts.require('LinkedList');
const AddressLinkedList = artifacts.require('AddressLinkedList');
const MockRegistry = artifacts.require('MockRegistry');
const MockElection = artifacts.require('MockElection');
const MockAccounts = artifacts.require('MockAccounts');
const MockLockedGold = artifacts.require('MockLockedGold');
const MockVault = artifacts.require('MockVault');
const Archive = artifacts.require('Archive');
const ProxyAdmin = artifacts.require('ProxyAdmin');

const { compareDeployedBytecodes } = require('./util');
const { primarySenderAddress } = require('../config');

const mockContracts = [MockRegistry, MockElection, MockAccounts, MockLockedGold, MockVault];

module.exports = async (deployer) => {
  await deployer.deploy(Migrations, { overwrite: false });
  await deployer.deploy(LinkedList, { overwrite: false });
  await deployer.link(LinkedList, AddressLinkedList);
  await deployer.deploy(AddressLinkedList, { overwrite: false });
  await deployer.link(AddressLinkedList, MockVault);

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

  if ((await mockRegistry.election()) !== mockElection.address) {
    await mockRegistry.setElection(mockElection.address);
  }

  if ((await mockRegistry.accounts()) !== mockAccounts.address) {
    await mockRegistry.setAccounts(mockAccounts.address);
  }

  if ((await mockRegistry.lockedGold()) !== mockLockedGold.address) {
    await mockRegistry.setLockedGold(mockLockedGold.address);
  }

  const { address: archiveAddress } = await deployer.deploy(Archive, { overwrite: false });
  const { address: proxyAdminAddress } = await deployer.deploy(ProxyAdmin, { overwrite: false });

  if (!(await mockVault.initialized())) {
    await mockVault.methods['initialize(address,address,address,address)'](
      mockRegistry.address,
      archiveAddress,
      primarySenderAddress,
      proxyAdminAddress,
      {
        value: new BigNumber(1e17)
      }
    );
  }
};