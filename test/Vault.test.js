const { assert } = require('./setup');

describe('Vault', function () {
  describe('State', function () {
    it('should have a proxy admin', async function () {
      return assert.equal(await this.vaultInstance.proxyAdmin(), this.proxyAdmin.address);
    });

    it('should have lockedGold', async function () {
      const lockedGold = await this.vaultInstance.lockedGold();
      const celoLockedGold = (await this.kit.contracts.getLockedGold()).address;

      return assert.equal(lockedGold, celoLockedGold);
    });

    it('should have a pending withdrawals linked list', async function () {
      const pendingWithdrawals = await this.vaultInstance.pendingWithdrawals();

      assert.property(pendingWithdrawals, 'head');
      assert.property(pendingWithdrawals, 'tail');
      return assert.property(pendingWithdrawals, 'numElements');
    });
  });
});
