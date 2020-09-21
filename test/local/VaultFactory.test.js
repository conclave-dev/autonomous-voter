const { assert } = require('./setup');

describe('VaultFactory', function () {
  describe('State', function () {
    it('should have app set', async function () {
      return assert.equal(await this.vaultFactory.app(), this.app.address);
    });

    it('should have portfolio set', async function () {
      return assert.equal(await this.vaultFactory.portfolio(), this.portfolio.address);
    });
  });

  describe('Methods ✅', function () {});

  describe('Methods 🛑', function () {
    it('should not create an instance from an invalid implementation', function () {
      return assert.isRejected(
        this.vaultFactory.createInstance(this.packageName, 'BadVault', this.registryContractAddress)
      );
    });

    it('should not create an instance from an invalid Celo Registry contract', function () {
      return assert.isRejected(this.vaultFactory.createInstance(this.packageName, 'Vault', this.zeroAddress));
    });
  });
});
