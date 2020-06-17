const { assert } = require('./setup');
const { registryContractAddress, primarySenderAddress } = require('../config');

describe('VaultFactory', function () {
  describe('initialize(App _app, Archive _archive)', function () {
    it('should initialize with deployed App and Archive addresses', async function () {
      assert.equal(await this.vaultFactory.app(), this.app.address, 'Did not match deployed App address');
      return assert.equal(
        await this.vaultFactory.archive(),
        this.archive.address,
        'Did not match deployed Archive address'
      );
    });
  });

  describe('createInstance(bytes memory _data)', function () {
    it('should not create an instance if the initial deposit is insufficient', function () {
      return assert.isRejected(this.vaultFactory.createInstance(registryContractAddress));
    });
  });
});
