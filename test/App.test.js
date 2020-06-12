const BigNumber = require('bignumber.js');
const { encodeCall } = require('@openzeppelin/upgrades');
const { assert, expect, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('App', () => {
  before(async () => {
    this.app = await contracts.App.deployed();
    this.archive = await contracts.Archive.deployed();
    this.vault = await contracts.Vault.deployed();
    this.vaultManager = await contracts.VaultManager.deployed();
    this.vaultFactory = await contracts.VaultFactory.deployed();
  });

  describe('initialize()', () => {
    it('should initialize with an owner', async () => {
      assert.equal(await this.app.owner(), primarySenderAddress, 'Owner does not match sender');
    });
  });

  describe('setContractImplementation(string contractName, address implementation)', () => {
    it('should not allow a non-owner to set implementation', async () => {
      await expect(
        this.app.setContractImplementation('Vault', this.vault.address, { from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
    });

    it('should allow its owner to set implementation', async () => {
      await expect(this.app.setContractImplementation('Vault', this.vault.address)).to.be.fulfilled;
    });

    it('should not allow setting zero-address as implementation', async () => {
      await expect(
        this.app.setContractImplementation('Vault', '0x0000000000000000000000000000000000000000')
      ).to.be.rejectedWith(Error);
    });
  });

  describe('setContractFactory(string contractName, address factory)', () => {
    it('should not allow a non-owner to set factory', async () => {
      await expect(
        this.app.setContractFactory('Vault', this.vaultFactory.address, { from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
    });

    it('should allow its owner to set factory', async () => {
      await expect(this.app.setContractFactory('Vault', this.vaultFactory.address)).to.be.fulfilled;
    });

    it('should not allow setting zero-address as factory', async () => {
      await expect(
        this.app.setContractFactory('Vault', '0x0000000000000000000000000000000000000000')
      ).to.be.rejectedWith(Error);
    });
  });

  describe('create(string contractName, address admin, bytes data', () => {
    it('should not allow any non-factory caller to create instance', async () => {
      await expect(this.app.create('Vault', primarySenderAddress, '0x0')).to.be.rejectedWith(Error);
    });

    it('should allow factories to create instance', async () => {
      // Set contract factory to an address that is not the vault factory
      await this.app.setContractFactory('Vault', primarySenderAddress);

      // Attempting to create an instance should now throw an error
      await expect(
        this.vaultFactory.createInstance(registryContractAddress, { value: new BigNumber('1e17') })
      ).to.be.rejectedWith(Error);

      // Set App's contract factory back to the VaultFactory's address
      await this.app.setContractFactory('Vault', this.vaultFactory.address);

      await expect(this.vaultFactory.createInstance(registryContractAddress, { value: new BigNumber('1e17') })).to.be
        .fulfilled;
    });
  });
});
