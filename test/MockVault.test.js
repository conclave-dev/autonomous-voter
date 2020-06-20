const BigNumber = require('bignumber.js');
const { assert } = require('./setup');
const { primarySenderAddress } = require('../config');

const mockCalculateVoteManagerRewards = (activeVotes, activeVotesWithoutRewards, rewardSharePercentage) => {
  // Vault calculateVoteManagerRewards logic in JS
  const rewards = activeVotes - activeVotesWithoutRewards;
  const rewardsPercent = rewards / 100;

  return Math.floor(rewardsPercent * rewardSharePercentage);
};

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

    const expectedManagerReward = mockCalculateVoteManagerRewards(
      mockActiveVotes,
      mockActiveVotesWithoutRewards,
      mockRewardSharePercentage
    );
    const actualManagerReward = new BigNumber(await this.mockVault.calculateVoteManagerRewards(primarySenderAddress));

    return assert.equal(
      actualManagerReward.isEqualTo(expectedManagerReward),
      true,
      'Expected and actual rewards were different'
    );
  });

  it('should calculate the voting manager rewards (small numbers)', async function () {
    const mockActiveVotes = 120;
    const mockActiveVotesWithoutRewards = 100;
    const mockRewardSharePercentage = await this.mockVault.managerCommission();

    await this.mockElection.setActiveVotesForGroupByAccount(
      primarySenderAddress,
      this.mockVault.address,
      mockActiveVotes
    );

    await this.mockVault.setActiveVotesWithoutRewardsForGroup(
      primarySenderAddress,
      await mockActiveVotesWithoutRewards
    );

    // When using SafeMath methods, the result would be 0 with the values above
    // due to order of operations + decimal numbers being rounded down.
    // Using Fixidity, we can hold off on the latter until the end, resulting in
    // the return value being 1
    const expectedManagerReward = mockCalculateVoteManagerRewards(
      mockActiveVotes,
      mockActiveVotesWithoutRewards,
      mockRewardSharePercentage
    );
    const actualManagerReward = new BigNumber(await this.mockVault.calculateVoteManagerRewards(primarySenderAddress));

    return assert.equal(
      actualManagerReward.isEqualTo(expectedManagerReward),
      true,
      'Expected and actual rewards were different'
    );
  });
});
