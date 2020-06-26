const { assert } = require('./setup');
const { registryContractAddress } = require('../config');

describe('Archive', () => {
  describe('initialize(address registry_)', function () {
    it('should initialize with an owner and registry', async function () {
      assert.equal(await this.archive.owner.call(), this.primarySender, 'Owner does not match sender');
      return assert.equal(await this.archive.registry.call(), registryContractAddress, 'Registry was incorrectly set');
    });
  });

  describe('setVaultFactory(address vaultFactory_)', function () {
    it('should not allow a non-owner to set vaultFactory', function () {
      // Return assertion so that it is properly handled (would always succeed otherwise)
      return assert.isRejected(this.archive.setVaultFactory(this.vaultFactory.address, { from: this.secondarySender }));
    });

    it('should allow its owner to set vaultFactory', async function () {
      await this.archive.setVaultFactory(this.vaultFactory.address);

      return assert.equal(
        await this.archive.vaultFactory.call(),
        this.vaultFactory.address,
        'Owner did not set vault factory'
      );
    });
  });
});
