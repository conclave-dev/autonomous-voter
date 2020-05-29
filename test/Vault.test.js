const { contract } = require('@openzeppelin/test-environment');
const { encodeCall } = require('@openzeppelin/upgrades');
const BigNumber = require('bignumber.js');
const {
  expect,
  kit,
  APP_CONTRACT_ADDRESS,
  DEFAULT_SENDER_ADDRESS,
  REGISTRY_CONTRACT_ADDRESS,
  TOKEN_BASE_MULTIPLIER
} = require('./config');

const VaultFactory = contract.fromArtifact('VaultFactory');

describe('Vault', function () {
  before(async function () {
    this.factory = await VaultFactory.new({ from: DEFAULT_SENDER_ADDRESS });
    this.defaultTx = { from: DEFAULT_SENDER_ADDRESS };
    this.accounts = await kit.contracts.getAccounts();
  });

  it('should create and initialize a Factory with App address', async function () {
    await expect(this.factory.initialize(APP_CONTRACT_ADDRESS, this.defaultTx)).to.not.be.rejected;
  });

  it('should create an instance and register a Celo account', async function () {
    const vaultInitializeCall = encodeCall('initialize', ['address'], [REGISTRY_CONTRACT_ADDRESS]);
    const depositAmount = new BigNumber(1).multipliedBy(TOKEN_BASE_MULTIPLIER).toString();
    const { logs } = await this.factory.createInstance(vaultInitializeCall, {
      from: DEFAULT_SENDER_ADDRESS,
      value: depositAmount
    });
    const { args, event } = logs[0];
    const vaultAddress = args[0];

    expect(await this.accounts.isAccount(this.factory.address)).to.equal(false);
    expect(await this.accounts.isAccount(vaultAddress)).to.equal(true);
    expect(await kit.web3.eth.getBalance(vaultAddress)).to.equal(depositAmount);
    expect(event).to.equal('InstanceCreated');
  });
});
