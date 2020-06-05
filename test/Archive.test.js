const { expect, assert } = require('chai').use(require('chai-as-promised'));
const { encodeCall } = require('@openzeppelin/upgrades');
const BigNumber = require('bignumber.js');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

const { setupLoader } = require('@openzeppelin/contract-loader');

const loader = setupLoader({
  provider: 'http://3.230.69.118:8545',
  defaultSender: primarySenderAddress,
  defaultGas: '20000000',
  defaultGasPrice: '100000000000'
});

const Archive = loader.truffle.fromArtifact('Archive', '0xa426709C243e0E077Ff26Bf18656155f40d6CD2E');
const VaultFactory = loader.truffle.fromArtifact('VaultFactory', '0x56B5FE5E5aCBa103E716d04ba6bE4Ccfd6B7850E');

describe('Archive', () => {
  describe('initialize(address _owner)', () => {
    it('should initialize with an owner', async () => {
      const owner = await Archive.owner();

      if (owner === '0x0000000000000000000000000000000000000000') {
        await Archive.initialize(primarySenderAddress);
      } else {
        await expect(Archive.initialize(primarySenderAddress)).to.be.rejectedWith(Error);
      }

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
      assert.equal(await Archive.vaultFactory(), VaultFactory.address, 'Owner did not set vault factory');
    });
  });

  describe('updateVault(address vault, address vaultAdmin)', () => {
    it('should initialize vault', async () => {
      const { logs: events } = await VaultFactory.createInstance(
        encodeCall('initializeVault', ['address', 'address'], [registryContractAddress, primarySenderAddress]),
        {
          from: primarySenderAddress,
          value: new BigNumber(1).multipliedBy('1e17')
        }
      );
      const [instanceCreated, adminCreated, instanceArchived] = events;
      const vault = loader.truffle.fromArtifact('Vault', instanceCreated.args[0]);

      assert.equal(vault.admin() === adminCreated.args[0], 'Vault was not initialized with correct proxy admin');
      assert.equal(vault.owner() === instanceArchived.args[1], 'Vault was not initialized with correct owner');
    });
  });
});
