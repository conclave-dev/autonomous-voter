const BigNumber = require('bignumber.js');
const { assert } = require('./setup');

describe('ManagerFactory', function () {
  describe('State', function () {
    it('should have app set', async function () {
      return assert.equal(await this.managerFactory.app(), this.app.address);
    });

    it('should have archive set', async function () {
      return assert.equal(await this.managerFactory.archive(), this.archive.address);
    });
  });

  describe('Methods ✅', function () {
    it('should create an instance from a valid implementation, commission, and minimum balance requirement', function () {
      const managerCommission = new BigNumber(1);
      const minimumBalanceRequirement = new BigNumber(1);

      return assert.isFulfilled(
        this.managerFactory.createInstance('AV', 'VoteManager', managerCommission, minimumBalanceRequirement)
      );
    });
  });

  describe('Methods 🛑', function () {
    it('should not create an instance from an invalid implementation', function () {
      return assert.isRejected(
        this.managerFactory.createInstance(
          'AV',
          'BadVoteManager',
          this.managerCommission,
          this.minimumBalanceRequirement
        )
      );
    });

    it('should not create an instance with an invalid/missing commission', function () {
      return assert.isRejected(
        this.managerFactory.createInstance('AV', 'VoteManager', null, this.minimumBalanceRequirement)
      );
    });

    it('should not create an instance with an invalid/missing minimum balance requirement', function () {
      return assert.isRejected(this.managerFactory.createInstance('AV', 'VoteManager', this.managerCommission, null));
    });
  });
});
