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
});
