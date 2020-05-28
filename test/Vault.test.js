const { contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const { encodeCall } = require('@openzeppelin/upgrades');
const { newKit } = require('@celo/contractkit');
const { APP_CONTRACT_ADDRESS, DEFAULT_SENDER_ADDRESS, REGISTRY_CONTRACT_ADDRESS } = require('./config');

const kit = newKit('http://localhost:8545');

const VaultFactory = contract.fromArtifact('VaultFactory');

describe('Vault', function () {
  it('should create and initialize a Factory with App address', async function () {
    this.factory = await VaultFactory.new({ from: DEFAULT_SENDER_ADDRESS });
    const { receipt } = await this.factory.initialize.sendTransaction(APP_CONTRACT_ADDRESS, {
      from: DEFAULT_SENDER_ADDRESS
    });

    expect(receipt.status).to.be.true;
  });

  it('should create an instance and register a Celo account', async function () {
    const vaultInitializeCall = encodeCall('initialize', ['address'], [REGISTRY_CONTRACT_ADDRESS]);
    const { logs } = await this.factory.createInstance.sendTransaction(vaultInitializeCall, {
      from: DEFAULT_SENDER_ADDRESS
    });
    const { args, event } = logs[0];
    const accounts = await kit.contracts.getAccounts();

    expect(await accounts.isAccount(this.factory.address)).to.equal(false);
    expect(await accounts.isAccount(args[0])).to.equal(true);
    expect(event).to.equal('InstanceCreated');
  });
});
