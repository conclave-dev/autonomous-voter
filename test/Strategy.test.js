const BigNumber = require('bignumber.js');
const { encodeCall } = require('@openzeppelin/upgrades');
const { assert, expect, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress } = require('../config');

describe('Strategy', () => {
  before(async () => {
    // Test values for strategy parameters
    this.rewardSharePercentage = '10';
    this.minimumManagedGold = new BigNumber('1e16').toString();
    this.archive = await contracts.Archive.deployed();

    const { logs } = await (await contracts.StrategyFactory.deployed()).createInstance(
      encodeCall(
        'initializeStrategy',
        ['address', 'address', 'uint256', 'uint256'],
        [this.archive.address, primarySenderAddress, this.rewardSharePercentage, this.minimumManagedGold]
      ),
      {
        value: new BigNumber('1e17')
      }
    );

    this.strategy = await contracts.Strategy.at(logs[0].args[0]);
  });

  describe('initializeStrategy(address archive, address owner, uint256 rewardSharePercentage, uint256 minimumManagedGold)', () => {
    it('should initialize with an owner, initial share percentage, and mininum managed gold', async () => {
      assert.equal(
        (await this.strategy.rewardSharePercentage()).toString(),
        this.rewardSharePercentage,
        'Invalid reward share percentage'
      );

      assert.equal(
        (await this.strategy.minimumManagedGold()).toString(),
        this.minimumManagedGold,
        'Invalid minimum managed gold'
      );
    });
  });

  describe('updateRewardSharePercentage(uint256 rewardSharePercentage)', () => {
    it('should update the reward share percentage', async () => {
      this.rewardSharePercentage = '20';

      await this.strategy.updateRewardSharePercentage(this.rewardSharePercentage);

      assert.equal(
        (await this.strategy.rewardSharePercentage()).toString(),
        this.rewardSharePercentage,
        'Failed to update reward share percentage'
      );
    });

    it('should not be able to update the share percentage from a non-owner account', async () => {
      await expect(this.strategy.updateRewardSharePercentage({ from: secondarySenderAddress })).to.be.rejectedWith(
        Error
      );
    });
  });

  describe('updateMinimumManagedGold(uint256 minimumManagedGold)', () => {
    it('should update the minimum managed gold', async () => {
      this.minimumManagedGold = new BigNumber('1e17').toString();

      await this.strategy.updateMinimumManagedGold(this.minimumManagedGold);

      assert.equal(
        (await this.strategy.minimumManagedGold()).toString(),
        this.minimumManagedGold,
        'Failed to update minimum managed gold'
      );
    });

    it('should not be able to update the minimum managed gold from a non-owner account', async () => {
      await expect(this.strategy.updateMinimumManagedGold({ from: secondarySenderAddress })).to.be.rejectedWith(Error);
    });
  });
});
