const BigNumber = require('bignumber.js');
const { assert } = require('./setup');
const { primarySenderAddress } = require('../config');

const mockUpdateManagerRewardsForGroup = (networkActiveVotes, localActiveVotes, managerCommission) => {
  // Vault updateManagerRewardsForGroup logic in JS
  const rewards = networkActiveVotes - localActiveVotes;
  const rewardsPercent = rewards / 100;

  return Math.floor(rewardsPercent * managerCommission);
};

describe('MockVault', function () {
  it('should calculate the vote manager rewards with random values', async function () {
    const mockActiveVotes = Math.floor(Math.random() * 1e8) + 1e6;
    const mockActiveVotesWithoutRewards = Math.floor(Math.random() * 1e5) + 1e3;
    const mockManagerCommission = Math.floor(Math.random() * 10) + 1;

    await this.mockElection.setActiveVotesForGroupByAccount(
      primarySenderAddress,
      this.mockVault.address,
      mockActiveVotes
    );

    await this.mockVault.setActiveVotesWithoutRewardsForGroup(
      primarySenderAddress,
      await mockActiveVotesWithoutRewards
    );

    await this.mockVault.setCommission(mockManagerCommission);

    const expectedManagerReward = mockUpdateManagerRewardsForGroup(
      mockActiveVotes,
      mockActiveVotesWithoutRewards,
      mockManagerCommission
    );

    const preUpdateManagerRewards = new BigNumber(await this.mockVault.managerRewards());

    await this.mockVault.updateManagerRewardsForGroup(primarySenderAddress);

    const postUpdateManagerRewards = new BigNumber(await this.mockVault.managerRewards());

    return assert.isTrue(
      postUpdateManagerRewards.minus(preUpdateManagerRewards).isEqualTo(expectedManagerReward),
      'Expected and actual rewards were different'
    );
  });

  it('should calculate the vote manager rewards with small values', async function () {
    const mockActiveVotes = 120;
    const mockActiveVotesWithoutRewards = 100;
    const mockManagerCommission = await this.mockVault.managerCommission();

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
    const expectedManagerReward = mockUpdateManagerRewardsForGroup(
      mockActiveVotes,
      mockActiveVotesWithoutRewards,
      mockManagerCommission
    );
    const preUpdateManagerRewards = new BigNumber(await this.mockVault.managerRewards());

    await this.mockVault.updateManagerRewardsForGroup(primarySenderAddress);

    const postUpdateManagerRewards = new BigNumber(await this.mockVault.managerRewards());

    return assert.isTrue(
      postUpdateManagerRewards.minus(preUpdateManagerRewards).isEqualTo(expectedManagerReward),
      'Expected and actual rewards were different'
    );
  });
});
