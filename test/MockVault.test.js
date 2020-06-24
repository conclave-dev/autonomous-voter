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
      // Mock the voting process which places the votes as pending
      await this.mockElection.voteForGroupByAccount(primarySenderAddress, this.mockVault.address, localActiveVotes);

      // Mock the vote activation
      await this.mockElection.activateForGroupByAccount(primarySenderAddress, this.mockVault.address);

      // Mock the reward distribution for further tests related to manager rewards
      await this.mockElection.distributeRewardForGroupByAccount(
        primarySenderAddress,
        this.mockVault.address,
        networkActiveVotes - this.mockActiveVotesWithoutRewards
      );

      await this.mockVault.setCommission(managerCommission);
      await this.mockVault.setManagerMinimumFunds(new BigNumber(localActiveVotes));
      await this.mockVault.setLocalActiveVotesForGroup(primarySenderAddress, localActiveVotes);

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

    await this.mockVault.updateManagerRewardsForGroup(primarySenderAddress);

    const postUpdateManagerRewards = new BigNumber(await this.mockVault.managerRewards());
    const updatedActiveVotes = new BigNumber(await this.mockVault.activeVotes(primarySenderAddress));

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

    await this.mockVault.updateManagerRewardsForGroup(primarySenderAddress);

    const postUpdateManagerRewards = new BigNumber(await this.mockVault.managerRewards());
    const updatedActiveVotes = new BigNumber(await this.mockVault.activeVotes(primarySenderAddress));

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
      const managerReward = new BigNumber(await this.mockVault.calculateVotingManagerRewards(primarySenderAddress));
      const activeVotes = new BigNumber(
        await this.mockElection.getActiveVotesForGroupByAccount(primarySenderAddress, this.mockVault.address)
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
          await this.mockElection.getActiveVotesForGroupByAccount(primarySenderAddress, this.mockVault.address)
        ).toFixed(0),
        activeVotes.minus(amountDiff).toFixed(0),
        `Updated voting balance doesn't match after revoking for initiating withdrawal`
      );
    });

    it('should not be able to initiate withdrawal with amount larger than total owned golds', async function () {
      const nonVotingBalance = new BigNumber(await this.mockVault.getNonvotingBalance());
      const activeVotes = new BigNumber(
        await this.mockElection.getActiveVotesForGroupByAccount(primarySenderAddress, this.mockVault.address)
      );
      const pendingVotes = new BigNumber(
        await this.mockElection.getPendingVotesForGroupByAccount(primarySenderAddress, this.mockVault.address)
      );
      const totalVotes = nonVotingBalance.plus(activeVotes).plus(pendingVotes);
      const withdrawalAmount = totalVotes.multipliedBy(2);

      assert.isRejected(this.mockVault.initiateWithdrawal(withdrawalAmount.toString()));
    });
  });

  describe('cancelWithdrawal(uint256 index, uint256 amount)', function () {
    it('should be able to cancel a valid pending withdrawal', async function () {
      const withdrawals = await this.mockLockedGold.getPendingWithdrawals(this.mockVault.address);
      const amount = new BigNumber(withdrawals[0][withdrawals[0].length - 1]);

      await this.mockVault.cancelWithdrawal(withdrawals[0].length - 1, amount.toString());

      assert.equal(
        new BigNumber(await this.mockVault.getNonvotingBalance()).toFixed(0),
        amount.toFixed(0),
        `Vault's non-voting balance should be updated with the cancelled withdrawal amount`
      );
    });

    it('should not be able to cancel non-existent withdrawal', async function () {
      const withdrawals = await this.mockLockedGold.getPendingWithdrawals(this.mockVault.address);
      const withdrawAmount = new BigNumber(1);

      assert.isRejected(this.mockVault.cancelWithdrawal(withdrawals.length, withdrawAmount.toString()));
    });
  });

  describe('withdraw()', function () {
    it('should be able to withdraw funds after the unlocking period has passed', async function () {
      const withdrawals = await this.mockLockedGold.getPendingWithdrawals(this.mockVault.address);

      // Since we only have 1 available withdrawal, we only need to get the amount of the first record
      const withdrawAmount = new BigNumber(withdrawals[0][0]);

      await this.mockVault.withdraw();

      const updatedWithdrawals = await this.mockLockedGold.getPendingWithdrawals(this.mockVault.address);

      assert.equal(
        updatedWithdrawals[0][0] !== withdrawAmount,
        true,
        `Vault's pending withdrawals didn't get updated after completing the withdrawal`
      );
    });

    it('should not be able to withdraw before the unlocking period has passed', async function () {
      // Set the unlocking period to 1 day so that no funds are transfered to the Vault
      await this.mockLockedGold.setUnlockingPeriod(86400);

      const nonVotingBalance = new BigNumber(await this.mockVault.getNonvotingBalance());
      const withdrawalAmount = nonVotingBalance.dividedBy(10).toFixed(0);

      await this.mockVault.initiateWithdrawal(withdrawalAmount.toString());

      assert.isRejected(this.mockVault.withdraw());
    });
  });

  it('should update manager rewards and active votes when its active votes are revoked', async function () {
    const voteManager = (await this.mockVault.getVoteManager())[0];

    if (voteManager === this.zeroAddress) {
      await this.mockVault.setVoteManager(this.persistentVoteManagerInstance.address);
    }

    const { networkActiveVotes, localActiveVotes, managerCommission } = this.generateRandomMockValues();

    await this.setMockActiveVotes(networkActiveVotes, localActiveVotes, managerCommission);

    const preRevokeNetworkActiveVotes = new BigNumber(
      await this.mockElection.getActiveVotesForGroupByAccount(primarySenderAddress, this.mockVault.address)
    );
    const preRevokeActiveVotes = new BigNumber(await this.mockVault.activeVotes(primarySenderAddress));
    const preRevokeManagerRewards = new BigNumber(await this.mockVault.managerRewards());
    const revokeAmount = new BigNumber(preRevokeNetworkActiveVotes).dividedBy(2).toFixed(0);

    await this.persistentVoteManagerInstance.revokeActive(
      this.mockVault.address,
      primarySenderAddress,
      revokeAmount,
      // Since we are using MockedElection, these can be zero values
      this.zeroAddress,
      this.zeroAddress,
      0
    );

    const postRevokeActiveVotes = new BigNumber(await this.mockVault.activeVotes(primarySenderAddress));
    const expectedManagerReward = new BigNumber(
      mockUpdateManagerRewardsForGroup(preRevokeNetworkActiveVotes, preRevokeActiveVotes, managerCommission)
    );
    const actualManagerReward = new BigNumber(await this.mockVault.managerRewards()).minus(preRevokeManagerRewards);

    assert.isTrue(expectedManagerReward.isEqualTo(actualManagerReward));
    return assert.equal(postRevokeActiveVotes, postRevokeActiveVotes);
  });
});
