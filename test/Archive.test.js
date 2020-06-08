const { encodeCall } = require('@openzeppelin/upgrades');
const BigNumber = require('bignumber.js');
const { assert, expect, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('Archive', () => {
  before(async () => {
    this.archive = await contracts.Archive.deployed();
    this.vaultFactory = await contracts.VaultFactory.deployed();
  });

  describe('initialize(address _owner)', () => {
    it('should initialize with an owner', async () => {
      assert.equal(await this.archive.owner(), primarySenderAddress, 'Owner does not match sender');
    });
  });

  describe('setVaultFactory(address _vaultFactory)', () => {
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

  describe('updateVault(address vault, address proxyAdmin)', () => {
    it('should initialize vault', async () => {
      const { logs: events } = await this.vaultFactory.createInstance(
        encodeCall('initializeVault', ['address', 'address'], [registryContractAddress, primarySenderAddress]),
        {
          value: new BigNumber(1).multipliedBy('1e17')
        }
      );
      const [instanceCreated, , instanceArchived] = events;
      const vault = await contracts.Vault.at(instanceCreated.args[0]);

      assert.equal(await vault.owner(), instanceArchived.args[1], 'Vault was not initialized with correct owner');
    });
  });
});
