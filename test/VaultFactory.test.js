const { encodeCall } = require('@openzeppelin/upgrades');
const { assert, expect, contracts } = require('./setup');
const { primarySenderAddress, registryContractAddress } = require('../config');

const { VaultFactory, App, Archive } = contracts;

describe('VaultFactory', () => {
  describe('initialize(App _app, IArchive _archive)', () => {
    it('should initialize with deployed App and Archive addresses', async () => {
      assert.equal(await VaultFactory.app(), App.address, 'Did not match deployed App address');
      assert.equal(await VaultFactory.archive(), Archive.address, 'Did not match deployed Archive address');
    });
  });

  describe('createInstance(bytes memory _data)', () => {
    it('should not create an instance if the initial deposit is insufficient', async () => {
      await expect(
        VaultFactory.createInstance(
          encodeCall('initializeVault', ['address', 'address'], [registryContractAddress, primarySenderAddress]),
          {
            from: primarySenderAddress,
            value: '0'
          }
        )
      ).to.be.rejectedWith(
        'Returned error: VM Exception while processing transaction: revert Insufficient funds for initial deposit -- Reason given: Insufficient funds for initial deposit.'
      );
    });
  });
});
