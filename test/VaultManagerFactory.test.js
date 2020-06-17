const { assert } = require('./setup');

describe('VaultManagerFactory', function () {
  describe('initialize(App _app, Archive _archive)', function () {
    it('should initialize with deployed App and Archive addresses', async function () {
      assert.equal(await this.vaultManagerFactory.app(), this.app.address, 'Did not match deployed App address');
      assert.equal(
        await this.vaultManagerFactory.archive(),
        this.archive.address,
        'Did not match deployed Archive address'
      );
    });
  });
});
