const BigNumber = require('bignumber.js');
const { assert, expect, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress } = require('../config');

describe('VaultManager', () => {
  before(async () => {
    // Test values for vaultManager parameters
    this.rewardSharePercentage = '10';
    this.minimumManageableBalanceRequirement = new BigNumber('1e16').toString();
    this.archive = await contracts.Archive.deployed();

    await (await contracts.VaultManagerFactory.deployed()).createInstance(
      this.rewardSharePercentage,
      this.minimumManageableBalanceRequirement
    );

    const vaultManagers = await this.archive.getVaultManagersByOwner(primarySenderAddress);
    this.vaultManager = await contracts.VaultManager.at(vaultManagers[vaultManagers.length - 1]);
  });

  describe('initialize(address archive, address owner, uint256 rewardSharePercentage, uint256 minimumManageableBalanceRequirement)', () => {
    it('should initialize with an owner, initial share percentage, and mininum managed gold', async () => {
      assert.equal(
        (await this.vaultManager.rewardSharePercentage()).toString(),
        this.rewardSharePercentage,
        'Invalid reward share percentage'
      );

      assert.equal(
        (await this.vaultManager.minimumManageableBalanceRequirement()).toString(),
        this.minimumManageableBalanceRequirement,
        'Invalid minimum managed gold'
      );
    });
  });

  describe('setRewardSharePercentage(uint256 rewardSharePercentage)', () => {
    it('should update the reward share percentage', async () => {
      this.rewardSharePercentage = '20';

      await this.vaultManager.setRewardSharePercentage(this.rewardSharePercentage);

      assert.equal(
        (await this.vaultManager.rewardSharePercentage()).toString(),
        this.rewardSharePercentage,
        'Failed to update reward share percentage'
      );
    });

    it('should not be able to update the share percentage from a non-owner account', async () => {
      await expect(this.vaultManager.setRewardSharePercentage({ from: secondarySenderAddress })).to.be.rejectedWith(
        Error
      );
    });
  });

  describe('setMinimumManageableBalanceRequirement(uint256 minimumManageableBalanceRequirement)', () => {
    it('should update the minimum managed gold', async () => {
      this.minimumManageableBalanceRequirement = new BigNumber('1e17').toString();

      await this.vaultManager.setMinimumManageableBalanceRequirement(this.minimumManageableBalanceRequirement);

      assert.equal(
        (await this.vaultManager.minimumManageableBalanceRequirement()).toString(),
        this.minimumManageableBalanceRequirement,
        'Failed to update minimum managed gold'
      );
    });

    it('should not be able to update the minimum managed gold from a non-owner account', async () => {
      await expect(
        this.vaultManager.setMinimumManageableBalanceRequirement({ from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
    });
  });

  describe('registerVault(uint256 vaultManagerIndex, uint256 amount)', () => {
    it('should not allow invalid vault to register', async () => {
      await expect(
        this.vaultManager.registerVault(primarySenderAddress, this.minimumManageableBalanceRequirement)
      ).to.be.rejectedWith(Error);
    });
  });
});
