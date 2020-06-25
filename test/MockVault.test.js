const BigNumber = require('bignumber.js');
const { assert } = require('./setup');

const mockUpdateManagerRewardsForGroup = (networkActiveVotes, localActiveVotes, managerCommission) => {
  // Vault updateManagerRewardsForGroup logic in JS
  const rewards = networkActiveVotes - localActiveVotes;
  const rewardsPercent = rewards / 100;

  return Math.floor(rewardsPercent * managerCommission);
};

describe('MockVault', function () {
  before(async function () {
    this.setMockActiveVotes = async (networkActiveVotes, localActiveVotes, managerCommission) => {
      await this.mockElection.resetVotesForAccount(this.mockVault.address);

      // Mock the voting process which places the votes as pending
      await this.mockElection.voteForGroupByAccount(this.primarySender, this.mockVault.address, localActiveVotes);

      // Mock the vote activation
      await this.mockElection.activateForGroupByAccount(this.primarySender, this.mockVault.address);

      // Mock the reward distribution for further tests related to manager rewards
      await this.mockElection.distributeRewardForGroupByAccount(
        this.primarySender,
        this.mockVault.address,
        networkActiveVotes - localActiveVotes
      );

      await this.mockVault.setCommission(managerCommission);
      await this.mockVault.setManagerMinimumBalanceRequirement(new BigNumber(localActiveVotes));
      await this.mockVault.setLocalActiveVotesForGroup(this.primarySender, localActiveVotes);

      // Set the unlocking period to 0 second so that funds can be withdrawn immediately
      await this.mockLockedGold.setUnlockingPeriod(0);
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

  describe('initiateWithdrawal(uint256 amount)', function () {
    it('should be able to initiate withdrawal without revoking votes if there is enough NonVoting golds', async function () {
      const nonVotingBalance = new BigNumber(await this.mockVault.getNonvotingBalance());
      const withdrawalAmount = nonVotingBalance.dividedBy(10).toFixed(0);

      await this.mockVault.initiateWithdrawal(withdrawalAmount.toString());

      assert.equal(
        new BigNumber(await this.mockVault.getNonvotingBalance()).toFixed(0),
        nonVotingBalance.minus(withdrawalAmount).toFixed(0),
        `Updated non-voting balance doesn't match after withdrawal`
      );
    });

    it('should be able to initiate withdrawal by revoking votes if there is not enough NonVoting golds', async function () {
      const nonVotingBalance = new BigNumber(await this.mockVault.getNonvotingBalance());
      const managerReward = new BigNumber(await this.mockVault.calculateVotingManagerRewards(this.primarySender));
      const activeVotes = new BigNumber(
        await this.mockElection.getActiveVotesForGroupByAccount(this.primarySender, this.mockVault.address)
      ).minus(managerReward);

      const amountDiff = new BigNumber(100);
      const withdrawalAmount = nonVotingBalance.plus(amountDiff);
      await this.mockVault.initiateWithdrawal(withdrawalAmount.toString());

      // In this scenario, it should use up all nonVoting golds of the vault
      assert.equal(
        new BigNumber(await this.mockVault.getNonvotingBalance()).toFixed(0),
        0,
        `Updated non-voting balance doesn't match after withdrawal`
      );

      // Then, check if the vault's active vote count has been updated as well (after the revoke)
      assert.equal(
        new BigNumber(
          await this.mockElection.getActiveVotesForGroupByAccount(this.primarySender, this.mockVault.address)
        ).toFixed(0),
        activeVotes.minus(amountDiff).toFixed(0),
        `Updated voting balance doesn't match after revoking for initiating withdrawal`
      );
    });

    it('should not be able to initiate withdrawal with amount larger than total owned golds', async function () {
      const nonVotingBalance = new BigNumber(await this.mockVault.getNonvotingBalance());
      const activeVotes = new BigNumber(
        await this.mockElection.getActiveVotesForGroupByAccount(this.primarySender, this.mockVault.address)
      );
      const pendingVotes = new BigNumber(
        await this.mockElection.getPendingVotesForGroupByAccount(this.primarySender, this.mockVault.address)
      );
      const totalVotes = nonVotingBalance.plus(activeVotes).plus(pendingVotes);
      const withdrawalAmount = totalVotes.multipliedBy(2);

      assert.isRejected(this.mockVault.initiateWithdrawal(withdrawalAmount.toString()));
    });
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
      await this.mockElection.getActiveVotesForGroupByAccount(primarySenderAddress, this.mockVault.address)
    ).multipliedBy(2);
    const currentActiveVotes = new BigNumber(await this.mockVault.activeVotes(primarySenderAddress));
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
    const expectedPendingWithdrawalTimestamp = (await kit.web3.eth.getBlock(blockNumber)).timestamp;

    // Generate a hash from the expected pending withdrawal values
    const expectedPendingWithdrawalHash = kit.web3.utils.soliditySha3(
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
