const LinkedList = artifacts.require('LinkedList');
const AddressLinkedList = artifacts.require('AddressLinkedList');
const SortedLinkedList = artifacts.require('SortedLinkedList');
const IntegerSortedLinkedList = artifacts.require('IntegerSortedLinkedList');
const Portfolio = artifacts.require('Portfolio');

module.exports = async (deployer, network) => {
  const overwrite = network === 'local' ? true : false;
  let deployLinkedList;
  let deployAddressLinkedList;
  let deploySortedLinkedList;
  let deployIntegerSortedLinkedList;

  try {
    deployLinkedList =
      overwrite || (await LinkedList.deployed()).address === '0x0000000000000000000000000000000000000000';
    deployAddressLinkedList =
      overwrite || (await LinkedList.deployed()).address === '0x0000000000000000000000000000000000000000';
    deploySortedLinkedList =
      overwrite || (await SortedLinkedList.deployed()).address === '0x0000000000000000000000000000000000000000';
    deployIntegerSortedLinkedList =
      overwrite || (await IntegerSortedLinkedList.deployed()).address === '0x0000000000000000000000000000000000000000';
  } catch (err) {
    console.error(err);
  }

  await deployer.deploy(LinkedList, { overwrite: deployLinkedList });
  await deployer.link(LinkedList, AddressLinkedList);
  await deployer.deploy(AddressLinkedList, { overwrite: deployAddressLinkedList });
  await deployer.link(AddressLinkedList, Portfolio);

  await deployer.link(LinkedList, IntegerSortedLinkedList);
  await deployer.deploy(SortedLinkedList, { overwrite: deploySortedLinkedList });
  await deployer.link(SortedLinkedList, IntegerSortedLinkedList);
  await deployer.deploy(IntegerSortedLinkedList, { overwrite: deployIntegerSortedLinkedList });
  await deployer.link(IntegerSortedLinkedList, Portfolio);
};
