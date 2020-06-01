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
    this.lockedGold = await kit.contracts.getLockedGold();
  });

  it('should create and initialize a Factory with App address', async function () {
    await expect(this.factory.initialize(APP_CONTRACT_ADDRESS, this.defaultTx)).to.not.be.rejected;
  });

  it('should create an instance and register a Celo account for sufficient initial deposit', async function () {
    const vaultInitializeCall = encodeCall('initialize', ['address'], [REGISTRY_CONTRACT_ADDRESS]);
    const depositAmount = new BigNumber(1).multipliedBy(TOKEN_BASE_MULTIPLIER).toString();
    const { logs } = await this.factory.createInstance(vaultInitializeCall, {
      from: DEFAULT_SENDER_ADDRESS,
      value: depositAmount
    });
    const { args, event } = logs[0];
    const vaultAddress = args[0];
    const vault = contract.fromArtifact('Vault', vaultAddress);

    expect(await this.accounts.isAccount(this.factory.address)).to.equal(false);
    expect(await this.accounts.isAccount(vaultAddress)).to.equal(true);

    expect((await vault.getUnmanagedGold()).toString()).to.equal(depositAmount);

    expect(event).to.equal('InstanceCreated');
  });

  it('should not create an instance for insufficient initial deposit', async function () {
    const vaultInitializeCall = encodeCall('initialize', ['address'], [REGISTRY_CONTRACT_ADDRESS]);
    const depositAmount = new BigNumber(0).multipliedBy(TOKEN_BASE_MULTIPLIER).toString();

    await expect(
      this.factory.createInstance(vaultInitializeCall, {
        from: DEFAULT_SENDER_ADDRESS,
        value: depositAmount
      })
    ).to.be.rejectedWith(
      'Returned error: VM Exception while processing transaction: revert Insufficient funds for initial deposit -- Reason given: Insufficient funds for initial deposit.'
    );
  });
});
