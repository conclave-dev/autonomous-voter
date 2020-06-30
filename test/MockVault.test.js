const BigNumber = require('bignumber.js');
const { assert } = require('./setup');
const { localRpcAPI } = require('../config');

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
        this.primarySender,
        this.mockVault.address,
        networkActiveVotes
      );
      await this.mockVault.setCommission(managerCommission);
      await this.mockVault.setLocalActiveVotesForGroup(this.primarySender, localActiveVotes);
    };

    this.generateRandomMockValues = () => ({
      networkActiveVotes: Math.floor(Math.random() * 1e8) + 1e6,
      localActiveVotes: Math.floor(Math.random() * 1e5) + 1e3,
      managerCommission: Math.floor(Math.random() * 10) + 1
    });
  });

  it('should calculate the vote manager rewards using random mocked values', async function () {
    const { networkActiveVotes, localActiveVotes, managerCommission } = this.generateRandomMockValues();
    const expectedManagerReward = mockUpdateManagerRewardsForGroup(
      networkActiveVotes,
      localActiveVotes,
      managerCommission
    );

    await this.setMockActiveVotes(networkActiveVotes, localActiveVotes, managerCommission);

    const preUpdateManagerRewards = new BigNumber(await this.mockVault.managerRewards());

    await this.mockVault.updateManagerRewardsForGroup(this.primarySender);

    const postUpdateManagerRewards = new BigNumber(await this.mockVault.managerRewards());
    const updatedActiveVotes = new BigNumber(await this.mockVault.activeVotes(this.primarySender));

    assert.isTrue(updatedActiveVotes.isEqualTo(networkActiveVotes), 'Vault activeVotes was not correctly updated');
    return assert.isTrue(
      postUpdateManagerRewards.minus(preUpdateManagerRewards).isEqualTo(expectedManagerReward),
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

    await this.setMockActiveVotes(mockNetworkActiveVotes, mockLocalActiveVotes, mockManagerCommission);

    const preUpdateManagerRewards = new BigNumber(await this.mockVault.managerRewards());

    await this.mockVault.updateManagerRewardsForGroup(this.primarySender);

    const postUpdateManagerRewards = new BigNumber(await this.mockVault.managerRewards());
    const updatedActiveVotes = new BigNumber(await this.mockVault.activeVotes(this.primarySender));

    assert.isTrue(updatedActiveVotes.isEqualTo(mockNetworkActiveVotes), 'Vault activeVotes was not correctly updated');
    return assert.isTrue(
      postUpdateManagerRewards.minus(preUpdateManagerRewards).isEqualTo(expectedManagerReward),
      'Expected and actual rewards were different'
    );
  });

  it('should update manager rewards and active votes when its active votes are revoked', async function () {
    const voteManager = await this.mockVault.manager();

    if (voteManager === this.zeroAddress) {
      await this.mockVault.setVoteManager(this.persistentVoteManagerInstance.address);
    }

    const { networkActiveVotes, localActiveVotes, managerCommission } = this.generateRandomMockValues();

    await this.setMockActiveVotes(networkActiveVotes, localActiveVotes, managerCommission);

    const preRevokeNetworkActiveVotes = new BigNumber(
      await this.mockElection.getActiveVotesForGroupByAccount(this.primarySender, this.mockVault.address)
    );
    const preRevokeActiveVotes = new BigNumber(await this.mockVault.activeVotes(this.primarySender));
    const preRevokeManagerRewards = new BigNumber(await this.mockVault.managerRewards());
    const revokeAmount = new BigNumber(preRevokeNetworkActiveVotes).dividedBy(2).toFixed(0);

    await this.persistentVoteManagerInstance.revokeActive(
      this.mockVault.address,
      this.primarySender,
      revokeAmount,
      // Since we are using MockedElection, these can be zero values
      this.zeroAddress,
      this.zeroAddress,
      0
    );

    const postRevokeActiveVotes = new BigNumber(await this.mockVault.activeVotes(this.primarySender));
    const expectedManagerReward = new BigNumber(
      mockUpdateManagerRewardsForGroup(preRevokeNetworkActiveVotes, preRevokeActiveVotes, managerCommission)
    );
    const actualManagerReward = new BigNumber(await this.mockVault.managerRewards()).minus(preRevokeManagerRewards);

    assert.isTrue(expectedManagerReward.isEqualTo(actualManagerReward));
    return assert.equal(postRevokeActiveVotes, postRevokeActiveVotes);
  });

  it('should remove a manager after it updates their reward total and initiates a withdrawal', async function () {
    const mockNetworkActiveVotes = new BigNumber(
      await this.mockElection.getActiveVotesForGroupByAccount(this.primarySender, this.mockVault.address)
    ).multipliedBy(2);
    const currentActiveVotes = new BigNumber(await this.mockVault.activeVotes(this.primarySender));
    const currentManagerRewards = await this.mockVault.managerRewards();
    const currentManagerCommission = await this.mockVault.managerCommission();
    const managerBeforeRemoval = await this.mockVault.manager();

    // Widen spread between network active votes and locally-stored active votes to mock reward accrual
    await this.setMockActiveVotes(mockNetworkActiveVotes, currentActiveVotes, await this.mockVault.managerCommission());

    const {
      receipt: { blockNumber }
    } = await this.mockVault.removeVoteManager();

    // Pending withdrawal value should be the previous managerRewards + rewards calculated during removal
    const expectedPendingWithdrawalValue = new BigNumber(
      mockUpdateManagerRewardsForGroup(mockNetworkActiveVotes, currentActiveVotes, currentManagerCommission)
    ).plus(currentManagerRewards);

    // Pending withdrawal timestamp should match the block's timestamp value
    const expectedPendingWithdrawalTimestamp = new BigNumber(
      (await this.kit.web3.eth.getBlock(blockNumber)).timestamp
    ).plus(this.kit.web3.currentProvider.existingProvider.host === localRpcAPI ? 21600 : 0);

    // Generate a hash from the expected pending withdrawal values
    const expectedPendingWithdrawalHash = this.kit.web3.utils.soliditySha3(
      // The recipient (need to use `managerBeforeRemoval` as `manager` should now be a zero address)
      managerBeforeRemoval,
      expectedPendingWithdrawalValue,
      expectedPendingWithdrawalTimestamp
    );

    // Confirm manager removal
    assert.equal(await this.mockVault.manager(), this.zeroAddress);

    // Verify pending withdrawal hash
    return assert.equal(expectedPendingWithdrawalHash, (await this.mockVault.pendingWithdrawals()).head);
  });
});
