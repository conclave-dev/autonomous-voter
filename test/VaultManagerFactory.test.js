const { assert, expect, contracts } = require('./setup');

describe('VaultManagerFactory', () => {
  before(async () => {
    this.app = await contracts.App.deployed();
    this.archive = await contracts.Archive.deployed();
    this.vaultManagerFactory = await contracts.VaultManagerFactory.deployed();
  });

  describe('initialize(App _app, Archive _archive)', () => {
    it('should initialize with deployed App and Archive addresses', async () => {
      assert.equal(await this.vaultManagerFactory.app(), this.app.address, 'Did not match deployed App address');
      assert.equal(
        await this.vaultManagerFactory.archive(),
        this.archive.address,
        'Did not match deployed Archive address'
      );
    });
  });
});
