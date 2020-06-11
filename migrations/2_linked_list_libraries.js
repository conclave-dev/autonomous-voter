const LinkedList = artifacts.require('LinkedList');
const AddressLinkedList = artifacts.require('AddressLinkedList');
const Strategy = artifacts.require('Strategy');

module.exports = async (deployer) => {
  await deployer.deploy(LinkedList);
  await deployer.link(LinkedList, AddressLinkedList);

  await deployer.deploy(AddressLinkedList);
  await deployer.link(AddressLinkedList, Strategy);
};
