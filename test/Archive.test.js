const { assert } = require('./setup');

describe('Archive', () => {
  describe('State', function () {
    it('should have a vault factory', async function () {
      return assert.equal(await this.archive.vaultFactory(), this.vaultFactory.address);
    });

    it('should have a manager factory', async function () {
      return assert.equal(await this.archive.managerFactory(), this.managerFactory.address);
    });

    it(`should have a user's vault instances`, async function () {
      const primarySenderVaults = await this.archive.getVaultsByOwner(this.primarySender);
      return assert.isTrue(primarySenderVaults.length > 0);
    });

    it(`should have a user's manager instances`, async function () {
      const primarySenderManagers = await this.archive.getManagersByOwner(this.primarySender);
      return assert.isTrue(primarySenderManagers.length > 0);
    });
  });
});
