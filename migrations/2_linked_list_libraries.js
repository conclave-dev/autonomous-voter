const LinkedList = artifacts.require('LinkedList');
const AddressLinkedList = artifacts.require('AddressLinkedList');
const Archive = artifacts.require('Archive');
const Vault = artifacts.require('Vault');
const MockVault = artifacts.require('MockVault');
const VotingVaultManager = artifacts.require('VotingVaultManager');

module.exports = async (deployer) => {
  await deployer.deploy(LinkedList, { overwrite: false });
  await deployer.link(LinkedList, AddressLinkedList);

  await deployer.deploy(AddressLinkedList, { overwrite: false });
  await deployer.link(AddressLinkedList, Archive);
  await deployer.link(LinkedList, Vault);
  await deployer.link(LinkedList, MockVault);
  await deployer.link(AddressLinkedList, VotingVaultManager);
};
