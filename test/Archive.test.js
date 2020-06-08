const { encodeCall } = require('@openzeppelin/upgrades');
const BigNumber = require('bignumber.js');
const { assert, expect, loader, contracts } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

const { Archive, VaultFactory } = contracts;

describe('Archive', () => {
  describe('initialize(address _owner)', () => {
    it('should initialize with an owner', async () => {
      assert.equal(await Archive.owner(), primarySenderAddress, 'Owner does not match sender');
    });
  });

  describe('setVaultFactory(address _vaultFactory)', () => {
    it('should not allow a non-owner to set vaultFactory', async () => {
      await expect(Archive.setVaultFactory(VaultFactory.address, { from: secondarySenderAddress })).to.be.rejectedWith(
        Error
      );
    });

    it('should allow its owner to set vaultFactory', async () => {
      await Archive.setVaultFactory(VaultFactory.address);
      await expect(Archive.setVaultFactory(VaultFactory.address, { from: secondarySenderAddress })).to.be.rejectedWith(
        Error
      );
      assert.equal(await Archive.vaultFactory(), VaultFactory.address, 'Owner did not set vault factory');
    });
  });

  describe('updateVault(address vault, address proxyAdmin)', () => {
    it('should initialize vault', async () => {
      const { logs: events } = await VaultFactory.createInstance(
        encodeCall('initializeVault', ['address', 'address'], [registryContractAddress, primarySenderAddress]),
        {
          from: primarySenderAddress,
          value: new BigNumber(1).multipliedBy('1e17')
        }
      );
      const [instanceCreated, , instanceArchived] = events;
      const vault = loader.truffle.fromArtifact('Vault', instanceCreated.args[0]);

      assert.equal(await vault.owner(), instanceArchived.args[1], 'Vault was not initialized with correct owner');
    });
  });
});
