const BigNumber = require('bignumber.js');
const { assert } = require('./setup');

describe('VaultFactory', function () {
  describe('State', function () {
    it('should have a minimum deposit set', async function () {
      return assert.isTrue(new BigNumber(await this.vaultFactory.MINIMUM_DEPOSIT()).isGreaterThan(0));
    });

    it('should have app set', async function () {
      return assert.equal(await this.vaultFactory.app(), this.app.address);
    });

    it('should have archive set', async function () {
      return assert.equal(await this.vaultFactory.archive(), this.archive.address);
    });
  });
});
