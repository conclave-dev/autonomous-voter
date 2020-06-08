const { encodeCall } = require('@openzeppelin/upgrades');
const BigNumber = require('bignumber.js');
const { assert, expect, contracts } = require('./setup');
const {
  primarySenderAddress,
  secondarySenderAddress,
  registryContractAddress,
  baklavaRpcAPI,
  defaultGas,
  defaultGasPrice
} = require('../config');

describe('Archive', () => {
  before(async () => {
    this.archive = await contracts.Archive.deployed();
    this.vaultFactory = await contracts.VaultFactory.deployed();
    this.strategyFactory = await contracts.StrategyFactory.deployed();
  });

  describe('initialize(address registry)', () => {
    it('should initialize with an owner and registry', async () => {
      assert.equal(await this.archive.owner(), primarySenderAddress, 'Owner does not match sender');
      assert.equal(await this.archive.registry(), registryContractAddress, 'Registry was incorrectly set');
    });
  });

  describe('setVaultFactory(address _vaultFactory)', () => {
    it('should not allow a non-owner to set vaultFactory', async () => {
      await expect(
        this.archive.setVaultFactory(this.vaultFactory.address, { from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
    });

    it('should allow its owner to set vaultFactory', async () => {
      await this.archive.setVaultFactory(this.vaultFactory.address);

      assert.equal(await this.archive.vaultFactory(), this.vaultFactory.address, 'Owner did not set vault factory');
    });
  });

  describe('updateVault(address vault, address proxyAdmin)', () => {
    it('should initialize vault', async () => {
      const { logs: events } = await this.vaultFactory.createInstance(
        encodeCall(
          'initializeVault',
          ['address', 'address', 'address'],
          [registryContractAddress, this.archive.address, primarySenderAddress]
        ),
        {
          value: new BigNumber(1).multipliedBy('1e17')
        }
      );
      const [instanceCreated, , instanceArchived] = events;
      const vault = await contracts.Vault.at(instanceCreated.args[0]);

      assert.equal(await vault.owner(), instanceArchived.args[1], 'Vault was not initialized with correct owner');
    });
  });

  describe('updateStrategy(address strategy, address proxyAdmin)', () => {
    it('should initialize strategy', async () => {
      const rewardSharePercentage = '10';
      const minimumManagedGold = new BigNumber('1e16').toString();

      const { logs: events } = await this.strategyFactory.createInstance(
        encodeCall(
          'initializeStrategy',
          ['address', 'address', 'uint256', 'uint256'],
          [this.archive.address, primarySenderAddress, rewardSharePercentage, minimumManagedGold]
        )
      );
      const [instanceCreated, , instanceArchived] = events;
      const strategy = await contracts.Strategy.at(instanceCreated.args[0]);

      assert.equal(await strategy.owner(), instanceArchived.args[1], 'Strategy was not initialized with correct owner');
    });
  });

  describe('setEpoch()', () => {
    it('should set epoch', async () => {
      const BaklavaArchive = require('@truffle/contract')(require('../build/contracts/Archive.json'));

      BaklavaArchive.setProvider(baklavaRpcAPI);
      BaklavaArchive.defaults({
        from: '0xB950E83464D7BB84e7420e460DEEc2A7ced656aA',
        gas: defaultGas,
        gasPrice: defaultGasPrice
      });

      const baklavaArchive = await BaklavaArchive.deployed();
      const { logs } = await baklavaArchive.setEpoch();
      const { 0: voterRewards, 1: activeVotes } = logs[0].args;

      assert.equal(!new BigNumber(voterRewards).isZero(), true, 'Voter rewards should be greater than zero');
      assert.equal(!new BigNumber(activeVotes).isZero(), true, 'Voter rewards should be greater than zero');
    });
  });
});
