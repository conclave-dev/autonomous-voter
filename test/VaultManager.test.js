const BigNumber = require('bignumber.js');
const { assert, expect, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress } = require('../config');

describe('VaultManager', function () {
  before(async function () {
    // Test values for vaultManager parameters
    this.rewardSharePercentage = '10';
    this.minimumManageableBalanceRequirement = new BigNumber('1e16').toString();

    await this.vaultManagerFactory.createInstance(this.rewardSharePercentage, this.minimumManageableBalanceRequirement);

    const vaultManagers = await this.archive.getVaultManagersByOwner(primarySenderAddress);
    this.vaultManagerInstance = await contracts.VaultManager.at(vaultManagers[vaultManagers.length - 1]);
  });

  describe('initialize(address archive, address owner, uint256 rewardSharePercentage, uint256 minimumManageableBalanceRequirement)', function () {
    it('should initialize with an owner, initial share percentage, and mininum managed gold', async function () {
      assert.equal(
        (await this.vaultManagerInstance.rewardSharePercentage()).toString(),
        this.rewardSharePercentage,
        'Invalid reward share percentage'
      );

      return assert.equal(
        (await this.vaultManagerInstance.minimumManageableBalanceRequirement()).toString(),
        this.minimumManageableBalanceRequirement,
        'Invalid minimum managed gold'
      );
    });
  });

  describe('setRewardSharePercentage(uint256 rewardSharePercentage)', function () {
    it('should update the reward share percentage', async function () {
      this.rewardSharePercentage = '20';

      await this.vaultManagerInstance.setRewardSharePercentage(this.rewardSharePercentage);

      return assert.equal(
        (await this.vaultManagerInstance.rewardSharePercentage()).toString(),
        this.rewardSharePercentage,
        'Failed to update reward share percentage'
      );
    });

    it('should not be able to update the share percentage from a non-owner account', function () {
      return expect(
        this.vaultManagerInstance.setRewardSharePercentage({ from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
    });
  });

  describe('setMinimumManageableBalanceRequirement(uint256 minimumManageableBalanceRequirement)', function () {
    it('should update the minimum managed gold', async function () {
      this.minimumManageableBalanceRequirement = new BigNumber('1e17').toString();

      await this.vaultManagerInstance.setMinimumManageableBalanceRequirement(this.minimumManageableBalanceRequirement);

      return assert.equal(
        (await this.vaultManagerInstance.minimumManageableBalanceRequirement()).toString(),
        this.minimumManageableBalanceRequirement,
        'Failed to update minimum managed gold'
      );
    });

    it('should not be able to update the minimum managed gold from a non-owner account', function () {
      return expect(
        this.vaultManagerInstance.setMinimumManageableBalanceRequirement({ from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
    });
  });

  describe('registerVault(uint256 vaultManagerIndex, uint256 amount)', function () {
    it('should not allow invalid vault to register', function () {
      return expect(
        this.vaultManagerInstance.registerVault(primarySenderAddress, this.minimumManageableBalanceRequirement)
      ).to.be.rejectedWith(Error);
    });
  });
});
