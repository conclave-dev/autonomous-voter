require('dotenv').config();

const chai = require('chai');
const BigNumber = require('bignumber.js');
const { contract } = require('@openzeppelin/test-environment');
const { encodeCall } = require('@openzeppelin/upgrades');

chai.use(require('chai-as-promised'));

const Archive = contract.fromArtifact('Archive');
const Vault = contract.fromArtifact('Vault');
const VaultFactory = contract.fromArtifact('VaultFactory');

const { APP_CONTRACT_ADDRESS, DEFAULT_SENDER_ADDRESS, REGISTRY_CONTRACT_ADDRESS } = process.env;
const TOKEN_BASE_MULTIPLIER = new BigNumber('1e18');
const defaultTx = { from: DEFAULT_SENDER_ADDRESS };
const INITIAL_DEPOSIT_AMOUNT = new BigNumber(1).multipliedBy(TOKEN_BASE_MULTIPLIER).toString();

const createArchive = async () => {
  const archive = await Archive.new(defaultTx);
  await archive.initialize(DEFAULT_SENDER_ADDRESS, defaultTx);
  return archive;
};

const createVaultFactory = async (appAddress, archiveAddress) => {
  const vaultFactory = await VaultFactory.new(defaultTx);
  await vaultFactory.initialize(appAddress, archiveAddress, defaultTx);
  return vaultFactory;
};

const createVault = async (registryAddress, ownerAddress, archive, vaultFactory) => {
  // Set vaultFactory in Archive so that our vault factory can update its `vaults` variable
  await archive.setVaultFactory(vaultFactory.address, defaultTx);

  const initializeVault = encodeCall('initialize', ['address', 'address'], [registryAddress, ownerAddress]);
  const { logs } = await vaultFactory.createInstance(initializeVault, {
    from: ownerAddress,
    value: INITIAL_DEPOSIT_AMOUNT
  });
  return Vault.at(logs[0].args[0]);
};

before(async function () {
  this.archive = await createArchive();
  this.vaultFactory = await createVaultFactory(APP_CONTRACT_ADDRESS, this.archive.address);
  this.vault = await createVault(REGISTRY_CONTRACT_ADDRESS, DEFAULT_SENDER_ADDRESS, this.archive, this.vaultFactory);
});

module.exports = {
  defaultTx,
  expect: chai.expect,
  createVault,
  kit: require('@celo/contractkit').newKit('http://localhost:8545'),
  APP_CONTRACT_ADDRESS,
  DEFAULT_SENDER_ADDRESS,
  REGISTRY_CONTRACT_ADDRESS,
  ZERO_ADDRESS: '0x0000000000000000000000000000000000000000',
  SECONDARY_ADDRESS: '0x48fF477891eCcd5177Ec8d66210EC2308fAc6eD6',
  INITIAL_DEPOSIT_AMOUNT
};
