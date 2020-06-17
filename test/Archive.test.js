const { assert, expect } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('Archive', () => {
  describe('initialize(address registry_)', function () {
    it('should initialize with an owner and registry', async function () {
      assert.equal(await this.archive.owner(), primarySenderAddress, 'Owner does not match sender');
      return assert.equal(await this.archive.registry(), registryContractAddress, 'Registry was incorrectly set');
    });
  });

  describe('setVaultFactory(address vaultFactory_)', function () {
    it('should not allow a non-owner to set vaultFactory', function () {
      // Return assertion so that it is properly handled (would always succeed otherwise)
      return expect(
        this.archive.setVaultFactory(this.vaultFactory.address, { from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
    });

    it('should allow its owner to set vaultFactory', async function () {
      await this.archive.setVaultFactory(this.vaultFactory.address);

      return assert.equal(
        await this.archive.vaultFactory(),
        this.vaultFactory.address,
        'Owner did not set vault factory'
      );
    });
  });
});
