const LinkedList = artifacts.require('LinkedList');
const AddressLinkedList = artifacts.require('AddressLinkedList');
const Archive = artifacts.require('Archive');
const VoteManager = artifacts.require('VoteManager');

module.exports = async (deployer) => {
  await deployer.deploy(LinkedList, { overwrite: false });
  await deployer.link(LinkedList, AddressLinkedList);

  await deployer.deploy(AddressLinkedList, { overwrite: false });
  await deployer.link(AddressLinkedList, Archive);
  await deployer.link(AddressLinkedList, VoteManager);
};
