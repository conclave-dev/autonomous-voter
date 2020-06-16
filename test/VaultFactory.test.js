const { assert, expect } = require('./setup');
const { registryContractAddress } = require('../config');

describe('VaultFactory', function () {
  describe('initialize(App _app, Archive _archive)', function () {
    it('should initialize with deployed App and Archive addresses', async function () {
      assert.equal(await this.vaultFactory.app(), this.app.address, 'Did not match deployed App address');
      assert.equal(await this.vaultFactory.archive(), this.archive.address, 'Did not match deployed Archive address');
    });
  });

  describe('createInstance(bytes memory _data)', function () {
    it('should not create an instance if the initial deposit is insufficient', async function () {
      await expect(this.vaultFactory.createInstance(registryContractAddress)).to.be.rejectedWith(Error);
    });
  });
});
