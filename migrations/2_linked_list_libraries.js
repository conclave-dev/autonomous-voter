const LinkedList = artifacts.require('LinkedList');
const AddressLinkedList = artifacts.require('AddressLinkedList');
const VaultManager = artifacts.require('VaultManager');
const Archive = artifacts.require('Archive');

module.exports = async (deployer) => {
  await deployer.deploy(LinkedList);
  await deployer.link(LinkedList, AddressLinkedList);

  await deployer.deploy(AddressLinkedList);
  await deployer.link(AddressLinkedList, VaultManager);
  await deployer.link(AddressLinkedList, Archive);
};
