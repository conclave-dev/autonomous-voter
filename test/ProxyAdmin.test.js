const { assert } = require('./setup');

describe('ProxyAdmin', function () {
  describe('initialize(App _app, address _owner)', function () {
    it('should only allow the owner to upgrade', function () {
      return assert.isFulfilled(this.proxyAdmin.upgradeProxy(this.vaultInstance.address, this.vault.address));
    });

    it('should not allow an unknown account to upgrade', function () {
      return assert.isRejected(
        this.proxyAdmin.upgradeProxy(this.secondarySender, this.vault.address, {
          from: this.secondarySender
        })
      );
    });
  });
});
