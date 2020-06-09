const { assert, expect, contracts } = require('./setup');

describe('StrategyFactory', () => {
  before(async () => {
    this.app = await contracts.App.deployed();
    this.archive = await contracts.Archive.deployed();
    this.strategyFactory = await contracts.StrategyFactory.deployed();
  });

  describe('initialize(App _app, IArchive _archive)', () => {
    it('should initialize with deployed App and Archive addresses', async () => {
      assert.equal(await this.strategyFactory.app(), this.app.address, 'Did not match deployed App address');
      assert.equal(
        await this.strategyFactory.archive(),
        this.archive.address,
        'Did not match deployed Archive address'
      );
    });
  });
});
