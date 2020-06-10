const BigNumber = require('bignumber.js');
const { assert, expect, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('Archive', () => {
  before(async () => {
    this.archive = await contracts.Archive.deployed();
    this.vaultFactory = await contracts.VaultFactory.deployed();
    this.strategyFactory = await contracts.StrategyFactory.deployed();
  });

  describe('initialize(address _owner)', () => {
    it('should initialize with an owner', async () => {
      assert.equal(await this.archive.owner(), primarySenderAddress, 'Owner does not match sender');
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

  describe('setVault(address vault, address proxyAdmin)', () => {
    it('should initialize vault', async () => {
      await this.vaultFactory.createInstance(registryContractAddress, this.archive.address, primarySenderAddress, {
        value: new BigNumber(1).multipliedBy('1e17')
      });
      const vault = await contracts.Vault.at(await this.archive.getVault(primarySenderAddress));

      assert.equal(await vault.owner(), primarySenderAddress, 'Vault was not initialized with correct owner');
    });
  });

  describe('setStrategy(address strategy, address proxyAdmin)', () => {
    it('should initialize strategy', async () => {
      const rewardSharePercentage = '10';
      const minimumManagedGold = new BigNumber('1e16').toString();

      await this.strategyFactory.createInstance(
        this.archive.address,
        primarySenderAddress,
        rewardSharePercentage,
        minimumManagedGold
      );
      const strategy = await contracts.Strategy.at(await this.archive.getStrategy(primarySenderAddress));

      assert.equal(await strategy.owner(), primarySenderAddress, 'Strategy was not initialized with correct owner');
    });
  });
});
