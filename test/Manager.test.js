const BigNumber = require('bignumber.js');
const { assert } = require('./setup');

describe('Manager', function () {
  describe('initialize(address archive, address owner, uint256 commission, uint256 minimumBalanceRequirement)', function () {
    it('should initialize with an owner, initial share percentage, and mininum managed gold', async function () {
      assert.isTrue(
        new BigNumber(await this.managerInstance.commission()).isEqualTo(this.managerCommission),
        'Invalid reward share percentage'
      );

      return assert.equal(
        (await this.managerInstance.minimumBalanceRequirement()).toString(),
        this.minimumBalanceRequirement,
        'Invalid minimum managed gold'
      );
    });
  });

  describe('setCommission(uint256 commission_)', function () {
    it('should update the reward share percentage', async function () {
      this.managerCommission = '20';

      await this.managerInstance.setCommission(this.managerCommission);

      return assert.equal(
        (await this.managerInstance.commission()).toString(),
        this.managerCommission,
        'Failed to update reward share percentage'
      );
    });

    it('should not be able to update the share percentage from a non-owner account', function () {
      return assert.isRejected(this.managerInstance.setCommission({ from: this.secondarySender }));
    });
  });

  describe('setMinimumBalanceRequirement(uint256 minimumBalanceRequirement)', function () {
    it('should update the minimum managed gold', async function () {
      this.minimumBalanceRequirement = new BigNumber('1e17').toString();

      await this.managerInstance.setMinimumBalanceRequirement(this.minimumBalanceRequirement);

      return assert.equal(
        (await this.managerInstance.minimumBalanceRequirement()).toString(),
        this.minimumBalanceRequirement,
        'Failed to update minimum managed gold'
      );
    });

    it('should not be able to update the minimum managed gold from a non-owner account', function () {
      return assert.isRejected(this.managerInstance.setMinimumBalanceRequirement({ from: this.secondarySender }));
    });
  });
});
