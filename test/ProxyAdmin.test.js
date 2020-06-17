const { assert } = require('./setup');
const { secondarySenderAddress } = require('../config');

describe('ProxyAdmin', function () {
  describe('initialize(App _app, address _owner)', function () {
    it('should only allow the owner to upgrade', function () {
      return assert.isFulfilled(this.proxyAdmin.upgradeProxy(this.vaultInstance.address, this.vault.address));
    });

    it('should not allow an unknown account to upgrade', function () {
      return assert.isRejected(
        this.proxyAdmin.upgradeProxy(secondarySenderAddress, this.vault.address, {
          from: secondarySenderAddress
        })
      );
    });
  });
});
