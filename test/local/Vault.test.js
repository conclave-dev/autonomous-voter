const { assert } = require('./setup');

describe('Vault', function () {
  describe('State', function () {
    it('should have a proxy admin', async function () {
      return assert.equal(await this.vaultInstance.proxyAdmin(), this.proxyAdmin.address);
    });
  });

  describe('Methods ✅', function () {
    it('should allow its owner to set its proxy admin', function () {
      return assert.isFulfilled(this.vaultInstance.setProxyAdmin(this.proxyAdmin.address));
    });
  });

  describe('Methods 🛑', function () {
    it('should not allow a non-owner to set its proxy admin', function () {
      return assert.isRejected(
        this.vaultInstance.setProxyAdmin(this.proxyAdmin.address, { from: this.secondarySender })
      );
    });
  });
});
