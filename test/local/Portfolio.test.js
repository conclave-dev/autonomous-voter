const { newKit } = require('@celo/contractkit');
const { assert } = require('./setup');
const { localRpcAPI, groupMaximum } = require('../../config');

describe('Portfolio', function () {
  before(async function () {
    this.election = await newKit(localRpcAPI).contracts.getElection();
  });

  describe('State', function () {
    it('should have a valid election', async function () {
      return assert.equal(this.election.address, await this.portfolio.election());
    });

    it('should have a valid groupMaximum', async function () {
      return assert.equal(groupMaximum, await this.portfolio.groupMaximum());
    });

    it('should have a manager only if voteAllocations is set', async function () {
      assert.equal(0, (await this.portfolio.voteAllocations).length);
      return assert.equal(this.zeroAddress, await this.portfolio.manager());
    });
  });


});
