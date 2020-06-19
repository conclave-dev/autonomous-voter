const BigNumber = require('bignumber.js');
const { assert, kit } = require('./setup');
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

  describe('withdraw(uint256 index)', function () {
    it('should be able to withdraw after the unlocking period has passed', async function () {
      await this.mockVault.deposit({
        value: new BigNumber('1e10')
      });

      const currentBalance = new BigNumber(await this.mockVault.getNonvotingBalance());
      const withdrawAmount = new BigNumber('1e9');

      // Set the unlocking period to 0 second so that funds can be withdrawn immediately
      await this.mockLockedGold.setUnlockingPeriod(0);

      await this.mockVault.initiateWithdrawal(withdrawAmount.toString());
      await this.mockVault.withdraw(0);

      assert.equal(
        new BigNumber(await this.mockVault.getNonvotingBalance()).toFixed(0),
        currentBalance.minus(withdrawAmount).toFixed(0),
        `Updated non-voting balance doesn't match after withdrawal`
      );

      assert.equal(
        new BigNumber(await kit.web3.eth.getBalance(this.mockVault.address)).toFixed(0),
        withdrawAmount.toFixed(0),
        `Vault's main balance doesn't match the withdrawn amount`
      );
    });

    it('should not be able to withdraw before the unlocking period has passed', async function () {
      const withdrawAmount = new BigNumber('1e9');

      // Set the unlocking period to 1 day so that no funds are transfered to the Vault
      await this.mockLockedGold.setUnlockingPeriod(86400);

      await this.mockVault.initiateWithdrawal(withdrawAmount.toString());

      assert.isRejected(this.mockVault.withdraw(0));
    });
  });
});
