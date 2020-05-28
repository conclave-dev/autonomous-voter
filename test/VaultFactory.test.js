const { contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const { encodeCall } = require('@openzeppelin/upgrades');
const { APP_CONTRACT_ADDRESS, DEFAULT_SENDER_ADDRESS, REGISTRY_CONTRACT_ADDRESS } = require('./config');

console.log('APP_CONTRACT_ADDRESS', APP_CONTRACT_ADDRESS);
console.log('DEFAULT_SENDER_ADDRESS', DEFAULT_SENDER_ADDRESS);

const VaultFactory = contract.fromArtifact('VaultFactory');

describe('VaultFactory', function () {
  it('should initialize with an App contract address', async function () {
    this.vaultFactoryContract = await VaultFactory.new({ from: DEFAULT_SENDER_ADDRESS });
    const { receipt } = await this.vaultFactoryContract.initialize.sendTransaction(APP_CONTRACT_ADDRESS, {
      from: DEFAULT_SENDER_ADDRESS
    });

    expect(receipt.status).to.be.true;
  });

  it('should create a Vault instance', async function () {
    const vaultInitializeCall = encodeCall('initialize', ['address'], [REGISTRY_CONTRACT_ADDRESS]);

    const { logs } = await this.vaultFactoryContract.createInstance.sendTransaction(vaultInitializeCall, {
      from: DEFAULT_SENDER_ADDRESS
    });

    expect(logs[0].event).to.equal('InstanceCreated');
  });
});
