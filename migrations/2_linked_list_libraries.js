const LinkedList = artifacts.require('LinkedList');
const AddressLinkedList = artifacts.require('AddressLinkedList');
const Archive = artifacts.require('Archive');
const Vault = artifacts.require('Vault');
const MockVault = artifacts.require('MockVault');
const VoteManager = artifacts.require('VoteManager');

module.exports = async (deployer, network) => {
  const overwrite = network === 'local' ? true : false;

  await deployer.deploy(LinkedList, { overwrite });
  await deployer.link(LinkedList, AddressLinkedList);
  await deployer.link(LinkedList, Vault);

  await deployer.deploy(AddressLinkedList, { overwrite });
  await deployer.link(AddressLinkedList, Archive);
  await deployer.link(LinkedList, Vault);
  await deployer.link(LinkedList, MockVault);
  await deployer.link(AddressLinkedList, VoteManager);
};
