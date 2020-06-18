const BigNumber = require('bignumber.js');
const { assert } = require('./setup');
const { primarySenderAddress } = require('../config');

describe('MockVault', function () {
  before(async function () {
    // Random values within defined ranges
    this.mockActiveVotes = Math.floor(Math.random() * 1e8) + 1e6;
    this.mockActiveVotesWithoutRewards = Math.floor(Math.random() * 1e5) + 1e3;
    this.mockRewardSharePercentage = Math.floor(Math.random() * 10) + 1;

    await this.mockElection.setActiveVotesForGroupByAccount(
      primarySenderAddress,
      this.mockVault.address,
      this.mockActiveVotes
    );

    await this.mockVault.setActiveVotesWithoutRewardsForGroup(
      primarySenderAddress,
      await this.mockActiveVotesWithoutRewards
    );

    await this.mockVault.setRewardSharePercentage(this.mockRewardSharePercentage);
  });

  it('should calculate the voting manager rewards for a voted group', async function () {
    // Vault _calculateVotingManagerRewards logic
    const differenceBetweenActiveVotes = this.mockActiveVotes - this.mockActiveVotesWithoutRewards;
    const rewardPoint = Math.floor(differenceBetweenActiveVotes / 100); // Emulate SafeMath's rounding down
    const expectedManagerReward = rewardPoint * this.mockRewardSharePercentage;
    const actualManagerReward = new BigNumber(await this.mockVault.calculateVotingManagerRewards(primarySenderAddress));

    return assert.equal(
      actualManagerReward.isEqualTo(expectedManagerReward),
      true,
      'Expected and actual rewards were different'
    );
  });
});
