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
  before(async function () {
    this.setMockActiveVotes = async (networkActiveVotes, localActiveVotes, managerCommission) => {
      await this.mockElection.setActiveVotesForGroupByAccount(
        primarySenderAddress,
        this.mockVault.address,
        networkActiveVotes
      );

      await this.mockVault.setCommission(managerCommission);

      await this.mockVault.setLocalActiveVotesForGroup(primarySenderAddress, await localActiveVotes);

      const preUpdateManagerRewards = new BigNumber(await this.mockVault.managerRewards());

      await this.mockVault.updateManagerRewardsForGroup(primarySenderAddress);

      const postUpdateManagerRewards = new BigNumber(await this.mockVault.managerRewards());

      return {
        preUpdate: preUpdateManagerRewards,
        postUpdate: postUpdateManagerRewards
      };
    };
  });

  it('should calculate the vote manager rewards using random mocked values', async function () {
    const mockNetworkActiveVotes = Math.floor(Math.random() * 1e8) + 1e6;
    const mockLocalActiveVotes = Math.floor(Math.random() * 1e5) + 1e3;
    const mockManagerCommission = Math.floor(Math.random() * 10) + 1;
    const expectedManagerReward = mockUpdateManagerRewardsForGroup(
      mockNetworkActiveVotes,
      mockLocalActiveVotes,
      mockManagerCommission
    );
    const { preUpdate, postUpdate } = await this.setMockActiveVotes(
      mockNetworkActiveVotes,
      mockLocalActiveVotes,
      mockManagerCommission
    );
    const updatedActiveVotes = new BigNumber(await this.mockVault.activeVotes(primarySenderAddress));

    assert.isTrue(updatedActiveVotes.isEqualTo(mockNetworkActiveVotes), 'Vault activeVotes was not correctly updated');
    return assert.isTrue(
      postUpdate.minus(preUpdate).isEqualTo(expectedManagerReward),
      'Expected and actual rewards were different'
    );
  });

  it('should calculate the vote manager rewards using small mocked values', async function () {
    const mockNetworkActiveVotes = 120;
    const mockLocalActiveVotes = 100;
    const mockManagerCommission = await this.mockVault.managerCommission();

    // When using SafeMath methods, the result would be 0 with the values above
    // due to order of operations + decimal numbers being rounded down.
    // Using Fixidity, we can hold off on the latter until the end, resulting in
    // the return value being 1
    const expectedManagerReward = mockUpdateManagerRewardsForGroup(
      mockNetworkActiveVotes,
      mockLocalActiveVotes,
      mockManagerCommission
    );

    const { preUpdate, postUpdate } = await this.setMockActiveVotes(
      mockNetworkActiveVotes,
      mockLocalActiveVotes,
      mockManagerCommission
    );
    const updatedActiveVotes = new BigNumber(await this.mockVault.activeVotes(primarySenderAddress));

    assert.isTrue(updatedActiveVotes.isEqualTo(mockNetworkActiveVotes), 'Vault activeVotes was not correctly updated');
    return assert.isTrue(
      postUpdate.minus(preUpdate).isEqualTo(expectedManagerReward),
      'Expected and actual rewards were different'
    );
  });
});
