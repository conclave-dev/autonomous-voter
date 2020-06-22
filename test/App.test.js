const BigNumber = require('bignumber.js');
const { assert } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('App', function () {
  describe('initialize()', function () {
    it('should initialize with an owner', async function () {
      return assert.equal(await this.app.owner(), primarySenderAddress, 'Owner does not match sender');
    });
  });

  describe('setContractImplementation(string contractName, address implementation)', function () {
    it('should allow its owner to set implementation', function () {
      assert.isRejected(
        this.app.setContractImplementation('Vault', this.vault.address, { from: secondarySenderAddress })
      );

      return assert.isFulfilled(this.app.setContractImplementation('Vault', this.vault.address));
    });
  });

  describe('setContractFactory(string contractName, address factory)', function () {
    it('should allow its owner to set factory', function () {
      assert.isRejected(
        this.app.setContractFactory('Vault', this.vaultFactory.address, { from: secondarySenderAddress })
      );

      return assert.isFulfilled(this.app.setContractFactory('Vault', this.vaultFactory.address));
    });
  });

  describe('create(string contractName, address admin, bytes data', function () {
    it('should allow authorized factories to create instances', function () {
      assert.isRejected(this.app.create('Vault', primarySenderAddress, '0x0'));

      return assert.isFulfilled(
        this.vaultFactory.createInstance('Vault', registryContractAddress, {
          value: new BigNumber('1e17')
        })
      );
    });
  });
});
