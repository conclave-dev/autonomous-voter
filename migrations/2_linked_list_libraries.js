const LinkedList = artifacts.require('LinkedList');
const AddressLinkedList = artifacts.require('AddressLinkedList');
const Archive = artifacts.require('Archive');
const Vault = artifacts.require('Vault');
const VoteManager = artifacts.require('VoteManager');

module.exports = async (deployer, network) => {
  const overwrite = network === 'local' ? true : false;
  let deployLinkedList;
  let deployAddressLinkedList;

  try {
    deployLinkedList =
      overwrite || (await LinkedList.deployed()).address === '0x0000000000000000000000000000000000000000';
    deployAddressLinkedList =
      overwrite || (await AddressLinkedList.deployed()).address === '0x0000000000000000000000000000000000000000';
  } catch (err) {
    console.error(err);
  }

  await deployer.deploy(LinkedList, { overwrite: deployLinkedList });
  await deployer.link(LinkedList, AddressLinkedList);
  await deployer.link(LinkedList, Vault);

  await deployer.deploy(AddressLinkedList, { overwrite: deployAddressLinkedList });
  await deployer.link(AddressLinkedList, Archive);
  await deployer.link(LinkedList, Vault);
  await deployer.link(AddressLinkedList, VoteManager);
};
