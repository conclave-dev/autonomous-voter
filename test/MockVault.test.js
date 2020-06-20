const BigNumber = require('bignumber.js');
const { assert } = require('./setup');
const { primarySenderAddress } = require('../config');

describe('MockVault', function () {
  it('should calculate the voting manager rewards (random numbers)', async function () {
    const mockActiveVotes = Math.floor(Math.random() * 1e8) + 1e6;
    const mockActiveVotesWithoutRewards = Math.floor(Math.random() * 1e5) + 1e3;
    const mockRewardSharePercentage = Math.floor(Math.random() * 10) + 1;

    await this.mockElection.setActiveVotesForGroupByAccount(
      primarySenderAddress,
      this.mockVault.address,
      mockActiveVotes
    );

    await this.mockVault.setActiveVotesWithoutRewardsForGroup(
      primarySenderAddress,
      await mockActiveVotesWithoutRewards
    );

    await this.mockVault.setRewardSharePercentage(mockRewardSharePercentage);

    // Vault calculateVotingManagerRewards logic
    const rewards = mockActiveVotes - mockActiveVotesWithoutRewards;
    const rewardsPercent = rewards / 100;
    const expectedManagerReward = Math.floor(rewardsPercent * mockRewardSharePercentage); // Round down, as decimals truncated
    const actualManagerReward = new BigNumber(await this.mockVault.calculateVotingManagerRewards(primarySenderAddress));

    return assert.equal(
      actualManagerReward.isEqualTo(expectedManagerReward),
      true,
      'Expected and actual rewards were different'
    );
  });
});
