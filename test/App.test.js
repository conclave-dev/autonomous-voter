const BigNumber = require('bignumber.js');
const { encodeCall } = require('@openzeppelin/upgrades');
const { assert, expect, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('App', () => {
  before(async () => {
    this.app = await contracts.App.deployed();
    this.archive = await contracts.Archive.deployed();
    this.vault = await contracts.Vault.deployed();
    this.strategy = await contracts.Strategy.deployed();
    this.vaultFactory = await contracts.VaultFactory.deployed();
    this.strategyFactory = await contracts.StrategyFactory.deployed();
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
      // For testing purpose, set our primary test account as the vault factory
      await this.app.setContractFactory('Vault', primarySenderAddress);

      await expect(
        this.app.create(
          'Vault',
          primarySenderAddress,
          encodeCall(
            'initialize',
            ['address', 'address', 'address', 'address'],
            [registryContractAddress, this.archive.address, primarySenderAddress, primarySenderAddress]
          ),
          {
            value: new BigNumber('1e17')
          }
        )
      ).to.be.fulfilled;

      // Reset the factory for other tests
      await this.app.setContractFactory('Vault', this.vaultFactory.address);
    });
  });
});
