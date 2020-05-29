require('dotenv').config();

const chai = require('chai');
const { contract } = require('@openzeppelin/test-environment');
const { encodeCall } = require('@openzeppelin/upgrades');

chai.use(require('chai-as-promised'));

const Vault = contract.fromArtifact('Vault');
const VaultFactory = contract.fromArtifact('VaultFactory');

const { APP_CONTRACT_ADDRESS, DEFAULT_SENDER_ADDRESS, REGISTRY_CONTRACT_ADDRESS } = process.env;
const defaultTx = { from: DEFAULT_SENDER_ADDRESS };

const createVaultFactory = async (appAddress) => {
  const vaultFactory = await VaultFactory.new(defaultTx);
  await vaultFactory.initialize(appAddress, defaultTx);
  return vaultFactory;
};

const createVault = async (registryAddress, ownerAddress, vaultFactory) => {
  const initializeVault = encodeCall('initialize', ['address', 'address'], [registryAddress, ownerAddress]);
  const { logs } = await vaultFactory.createInstance(initializeVault, defaultTx);
  return Vault.at(logs[0].args[0]);
};

before(async function () {
  this.vaultFactory = await createVaultFactory(APP_CONTRACT_ADDRESS);
  this.vault = await createVault(REGISTRY_CONTRACT_ADDRESS, DEFAULT_SENDER_ADDRESS, this.vaultFactory);
});

module.exports = {
  defaultTx,
  expect: chai.expect,
  kit: require('@celo/contractkit').newKit('http://localhost:8545'),
  APP_CONTRACT_ADDRESS,
  DEFAULT_SENDER_ADDRESS,
  REGISTRY_CONTRACT_ADDRESS,
  ZERO_ADDRESS: '0x0000000000000000000000000000000000000000',
  SECONDARY_ADDRESS: '0x57c445eaea6b8782b75a50e2069fc209386541f1'
};
