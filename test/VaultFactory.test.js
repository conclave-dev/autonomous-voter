const BigNumber = require('bignumber.js');
const { assert } = require('./setup');

describe('VaultFactory', function () {
  describe('State', function () {
    it('should have a minimum deposit set', async function () {
      return assert.isTrue(new BigNumber(await this.vaultFactory.MINIMUM_DEPOSIT()).isGreaterThan(0));
    });

    it('should have app set', async function () {
      return assert.equal(await this.vaultFactory.app(), this.app.address);
    });

    it('should have archive set', async function () {
      return assert.equal(await this.vaultFactory.archive(), this.archive.address);
    });
  });

  describe('Methods ✅', function () {
    it('should create an instance from a valid implementation and Celo Registry contract', function () {
      return assert.isFulfilled(
        this.vaultFactory.createInstance('Vault', this.registryContractAddress, {
          value: new BigNumber('1e17')
        })
      );
    });
  });

  describe('Methods 🛑', function () {
    it('should not create an instance with an insufficient deposit amount', async function () {
      const depositBelowMinimum = new BigNumber(await this.vaultFactory.MINIMUM_DEPOSIT()).minus(1);

      return assert.isRejected(
        this.vaultFactory.createInstance('Vault', this.registryContractAddress, {
          value: depositBelowMinimum
        })
      );
    });

    it('should not create an instance from an invalid implementation', function () {
      return assert.isRejected(
        this.vaultFactory.createInstance('BadVault', this.registryContractAddress, {
          value: new BigNumber('1e17')
        })
      );
    });

    it('should not create an instance from an invalid Celo Registry contract', function () {
      return assert.isRejected(
        this.vaultFactory.createInstance('Vault', this.zeroAddress, {
          value: new BigNumber('1e17')
        })
      );
    });
  });
});
