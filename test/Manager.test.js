const BigNumber = require('bignumber.js');
const { assert } = require('./setup');

describe('Manager', function () {
  describe('State', function () {
    it('should initialize with a manager commission', async function () {
      return assert.equal((await this.managerInstance.commission()).toString(), this.managerCommission);
    });

    it('should initialize with a mininum required balance', async function () {
      return assert.equal(
        (await this.managerInstance.minimumBalanceRequirement()).toString(),
        this.minimumBalanceRequirement
      );
    });
  });

  describe('Methods ✅', function () {
    it('should allow its owner to update the manager commission', async function () {
      this.managerCommission = '20';

      await this.managerInstance.setCommission(this.managerCommission);

      return assert.equal((await this.managerInstance.commission()).toString(), this.managerCommission);
    });

    it('should allow its owner to update the minimum required balance', async function () {
      this.minimumBalanceRequirement = new BigNumber('1e11').toString();

      await this.managerInstance.setMinimumBalanceRequirement(this.minimumBalanceRequirement);

      return assert.equal(
        (await this.managerInstance.minimumBalanceRequirement()).toString(),
        this.minimumBalanceRequirement
      );
    });
  });

  describe('Methods 🛑', function () {
    it('should not allow non-owner account to update the manager commission', function () {
      return assert.isRejected(this.managerInstance.setCommission({ from: this.secondarySender }));
    });

    it('should not allow non-owner account to update the minimum required balance', function () {
      return assert.isRejected(this.managerInstance.setMinimumBalanceRequirement({ from: this.secondarySender }));
    });
  });
});
