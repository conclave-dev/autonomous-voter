const LinkedList = artifacts.require('LinkedList');
const AddressLinkedList = artifacts.require('AddressLinkedList');
const Archive = artifacts.require('Archive');
const MockArchive = artifacts.require('MockArchive');
const Vault = artifacts.require('Vault');
const VotingVaultManager = artifacts.require('VotingVaultManager');

module.exports = async (deployer) => {
  await deployer.deploy(LinkedList, { overwrite: false });
  await deployer.link(LinkedList, AddressLinkedList);

  await deployer.deploy(AddressLinkedList, { overwrite: false });
  await deployer.link(AddressLinkedList, Archive);
  await deployer.link(AddressLinkedList, MockArchive);
  await deployer.link(AddressLinkedList, Vault);
  await deployer.link(AddressLinkedList, VotingVaultManager);
};
