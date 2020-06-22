const BigNumber = require('bignumber.js');
const { assert } = require('./setup');
const { primarySenderAddress } = require('../config');

describe('MockVault', function () {
  before(async function () {
    // Random values within defined ranges
    this.mockActiveVotes = Math.floor(Math.random() * 1e8) + 1e6;
    this.mockActiveVotesWithoutRewards = Math.floor(Math.random() * 1e5) + 1e3;
    this.mockRewardSharePercentage = Math.floor(Math.random() * 10) + 1;

    await this.mockVault.deposit({ value: new BigNumber(1e16) });

    // Mock the voting process which places the votes as pending
    await this.mockElection.voteForGroupByAccount(
      primarySenderAddress,
      this.mockVault.address,
      this.mockActiveVotesWithoutRewards
    );

    // Mock the vote activation
    await this.mockElection.activateForGroupByAccount(primarySenderAddress, this.mockVault.address);

    // Mock the reward distribution for further tests related to manager rewards
    await this.mockElection.distributeRewardForGroupByAccount(
      primarySenderAddress,
      this.mockVault.address,
      this.mockActiveVotes - this.mockActiveVotesWithoutRewards
    );

    // Mock the locally stored initial vote count (without reward) on MockVault
    await this.mockVault.setActiveVotesWithoutRewardsForGroup(
      primarySenderAddress,
      await this.mockActiveVotesWithoutRewards
    );

    await this.mockVault.setRewardSharePercentage(this.mockRewardSharePercentage);
    await this.mockVault.setMinimumManageableBalanceRequirement(new BigNumber(this.mockActiveVotesWithoutRewards));
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

  // describe('withdraw(uint256 index)', function () {
  //   it('should be able to withdraw after the unlocking period has passed', async function () {
  //     await this.mockVault.deposit({
  //       value: new BigNumber('1e10')
  //     });

  //     const currentBalance = new BigNumber(await this.mockVault.getNonvotingBalance());
  //     const withdrawAmount = new BigNumber('1e9');

  //     // Set the unlocking period to 0 second so that funds can be withdrawn immediately
  //     await this.mockLockedGold.setUnlockingPeriod(0);

  //     await this.mockVault.initiateWithdrawal(withdrawAmount.toString());
  //     await this.mockVault.withdraw(0);

  //     assert.equal(
  //       new BigNumber(await this.mockVault.getNonvotingBalance()).toFixed(0),
  //       currentBalance.minus(withdrawAmount).toFixed(0),
  //       `Updated non-voting balance doesn't match after withdrawal`
  //     );

  //     assert.equal(
  //       new BigNumber(await kit.web3.eth.getBalance(this.mockVault.address)).toFixed(0),
  //       withdrawAmount.toFixed(0),
  //       `Vault's main balance doesn't match the withdrawn amount`
  //     );
  //   });

  //   it('should not be able to withdraw before the unlocking period has passed', async function () {
  //     const withdrawAmount = new BigNumber('1e9');

  //     // Set the unlocking period to 1 day so that no funds are transfered to the Vault
  //     await this.mockLockedGold.setUnlockingPeriod(86400);

  //     await this.mockVault.initiateWithdrawal(withdrawAmount.toString());

  //     assert.isRejected(this.mockVault.withdraw(0));
  //   });
  // });

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

      await this.mockVault.cancelWithdrawal(2, amount.toString());

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
});
