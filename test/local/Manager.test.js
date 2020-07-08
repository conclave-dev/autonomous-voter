const BigNumber = require('bignumber.js');
const { assert } = require('./setup');

describe('Manager', function () {
  describe('State', function () {
    it('should initialize with a reference to the archive contract', async function () {
      return assert.equal(await this.managerInstance.archive(), this.archive.address);
    });

    it('should initialize with a valid proxy admin', async function () {
      return assert.notEqual(await this.managerInstance.proxyAdmin(), this.zeroAddress);
    });

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
    it('should allow its owner to update the proxy admin', async function () {
      await this.managerInstance.setProxyAdmin(this.secondarySender);

      return assert.equal(await this.managerInstance.proxyAdmin(), this.secondarySender);
    });

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
    it('should not allow non-owner account to update the proxy admin', function () {
      return assert.isRejected(
        this.managerInstance.setProxyAdmin(this.secondarySender, { from: this.secondarySender })
      );
    });

    it('should not allow zero-address when updating the proxy admin', function () {
      return assert.isRejected(this.managerInstance.setProxyAdmin(this.zeroAddress));
    });

    it('should not allow percentage value lower than 1 to update the manager commission', function () {
      return assert.isRejected(this.managerInstance.setCommission(0));
    });

    it('should not allow percentage value higher than 100 to update the manager commission', function () {
      return assert.isRejected(this.managerInstance.setCommission(101));
    });

    it('should not allow non-owner account to update the manager commission', function () {
      return assert.isRejected(this.managerInstance.setCommission({ from: this.secondarySender }));
    });

    it('should not allow 0 as to update the minimum required balance', function () {
      return assert.isRejected(this.managerInstance.setMinimumBalanceRequirement(0));
    });

    it('should not allow non-owner account to update the minimum required balance', function () {
      return assert.isRejected(this.managerInstance.setMinimumBalanceRequirement({ from: this.secondarySender }));
    });
  });
});
