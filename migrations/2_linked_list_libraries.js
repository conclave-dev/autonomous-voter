const LinkedList = artifacts.require('LinkedList');
const AddressLinkedList = artifacts.require('AddressLinkedList');
const Archive = artifacts.require('Archive');
const Vault = artifacts.require('Vault');
const VoteManager = artifacts.require('VoteManager');

module.exports = async (deployer, network) => {
  const overwrite = network === 'local' ? true : false;
  const deployLinkedList =
    overwrite || (await LinkedList.deployed()).address === '0x0000000000000000000000000000000000000000';
  const deployAddressLinkedList =
    overwrite || (await AddressLinkedList.deployed()).address === '0x0000000000000000000000000000000000000000';

  await deployer.deploy(LinkedList, { overwrite: deployLinkedList });
  await deployer.link(LinkedList, AddressLinkedList);
  await deployer.link(LinkedList, Vault);

  await deployer.deploy(AddressLinkedList, { overwrite: deployAddressLinkedList });
  await deployer.link(AddressLinkedList, Archive);
  await deployer.link(LinkedList, Vault);
  await deployer.link(AddressLinkedList, VoteManager);
};
