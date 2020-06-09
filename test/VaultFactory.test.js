const { encodeCall } = require('@openzeppelin/upgrades');
const { assert, expect, contracts } = require('./setup');
const { primarySenderAddress, registryContractAddress } = require('../config');

describe('VaultFactory', () => {
  before(async () => {
    this.app = await contracts.App.deployed();
    this.archive = await contracts.Archive.deployed();
    this.vaultFactory = await contracts.VaultFactory.deployed();
  });

  describe('initialize(App _app, IArchive _archive)', () => {
    it('should initialize with deployed App and Archive addresses', async () => {
      assert.equal(await this.vaultFactory.app(), this.app.address, 'Did not match deployed App address');
      assert.equal(await this.vaultFactory.archive(), this.archive.address, 'Did not match deployed Archive address');
    });
  });

  describe('createInstance(bytes memory _data)', () => {
    it('should not create an instance if the initial deposit is insufficient', async () => {
      await expect(
        this.vaultFactory.createInstance(
          encodeCall(
            'initializeVault',
            ['address', 'address', 'address'],
            [registryContractAddress, this.archive.address, primarySenderAddress]
          ),
          {
            value: 0
          }
        )
      ).to.be.rejectedWith(Error);
    });
  });
});
