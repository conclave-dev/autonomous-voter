const { assert } = require('./setup');
const { rewardExpiration, holderRewardPercentage } = require('../../config');

describe.only('RewardManager', function () {
  before(async function () {
    await this.rewardManager.setBank(this.mockBank.address);
    this.lockedGold = (await this.kit._web3Contracts.getLockedGold()).methods;
  });

  after(async function () {
    await this.rewardManager.setBank(this.bank.address);
  });

  describe('State', function () {
    it('should have the correct reward expiration', async function () {
      return assert.equal(await this.bank.rewardExpiration(), rewardExpiration);
    });

    it('should have the correct holder reward percentage', async function () {
      return assert.equal(await this.bank.holderRewardPercentage(), holderRewardPercentage);
    });
  });
});
