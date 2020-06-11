const { assert, expect, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('Archive', () => {
  before(async () => {
    this.archive = await contracts.Archive.deployed();
    this.vaultFactory = await contracts.VaultFactory.deployed();
    this.vaultManagerFactory = await contracts.VaultManagerFactory.deployed();
  });

  describe('initialize(address registry_)', () => {
    it('should initialize with an owner and registry', async () => {
      assert.equal(await this.archive.owner(), primarySenderAddress, 'Owner does not match sender');
      assert.equal(await this.archive.registry(), registryContractAddress, 'Registry was incorrectly set');
    });
  });

  describe('setVaultFactory(address vaultFactory_)', () => {
    it('should not allow a non-owner to set vaultFactory', async () => {
      await expect(
        this.archive.setVaultFactory(this.vaultFactory.address, { from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
    });

    it('should allow its owner to set vaultFactory', async () => {
      await this.archive.setVaultFactory(this.vaultFactory.address);

      assert.equal(await this.archive.vaultFactory(), this.vaultFactory.address, 'Owner did not set vault factory');
    });
  });
});
