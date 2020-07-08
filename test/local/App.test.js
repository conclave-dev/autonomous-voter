const BigNumber = require('bignumber.js');
const { assert } = require('./setup');
const { registryContractAddress } = require('../../config');

describe('App', function () {
  describe('State', function () {
    it('should initialize with an owner', async function () {
      return assert.equal(await this.app.owner(), this.primarySender);
    });
  });

  describe('Methods ✅', function () {
    it('should allow its owner to set contract implementation', function () {
      return assert.isFulfilled(this.app.setContractImplementation('Vault', this.vault.address));
    });

    it('should allow its owner to set contract factory', function () {
      return assert.isFulfilled(this.app.setContractFactory('Vault', this.vaultFactory.address));
    });

    it('should allow authorized contract factories to create instances', function () {
      return assert.isFulfilled(
        this.vaultFactory.createInstance('Vault', registryContractAddress, {
          value: new BigNumber('1e17')
        })
      );
    });
  });

  describe('Methods 🛑', function () {
    it('should not allow non-owner to set contract implementation', function () {
      return assert.isRejected(
        this.app.setContractImplementation('Vault', this.vault.address, { from: this.secondarySender })
      );
    });

    it('should not allow non-owner to set contract factory', function () {
      return assert.isRejected(
        this.app.setContractFactory('Vault', this.vaultFactory.address, { from: this.secondarySender })
      );
    });

    it('should not allow unauthorized address to create instances', function () {
      return assert.isRejected(this.app.create('Vault', this.primarySender, '0x0'));
    });
  });
});
