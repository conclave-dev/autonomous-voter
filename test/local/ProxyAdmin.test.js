const { assert } = require('./setup');

describe('ProxyAdmin', function () {
  describe('State', function () {
    it('should have owner set', async function () {
      return assert.equal(await this.proxyAdmin.owner(), this.primarySender);
    });

    it('should have app set', async function () {
      return assert.equal(await this.proxyAdmin.app(), this.app.address);
    });
  });

  describe('Methods ✅', function () {
    it('should allow the owner to upgrade the proxy with a valid implementation', async function () {
      return assert.isFulfilled(
        this.proxyAdmin.upgradeProxyImplementation(this.vaultInstance.address, this.vault.address)
      );
    });
  });

  describe('Methods 🛑', function () {});
});
