const { assert } = require('./setup');
const { time } = require('@openzeppelin/test-helpers');
const { default: BigNumber } = require('bignumber.js');
const { rewardExpiration, holderRewardPercentage } = require('../../config');

const gotoNextEpoch = async (test, skip = 1) => {
  await time.advanceBlockTo(
    new BigNumber(await test.kit.web3.eth.getBlockNumber()).plus(test.epochSize * skip).toFixed(0)
  );
};

describe('RewardManager', function () {
  before(async function () {
    await this.mockBank.reset();
    await this.mockRewardManager.reset();
    await this.mockRewardManager.setRewardExpiration(rewardExpiration);

    // Fast-forward to the next epoch
    this.epochSize = new BigNumber(await this.mockRewardManager.getEpochSize());
    await gotoNextEpoch(this);
  });

  describe('State', function () {
    it('should have the correct reward expiration', async function () {
      return assert.equal(await this.mockRewardManager.rewardExpiration(), rewardExpiration);
    });

    it('should have the correct holder reward percentage', async function () {
      return assert.equal(await this.mockRewardManager.holderRewardPercentage(), holderRewardPercentage);
    });
  });

  describe('Methods ✅', function () {
    it('should allow owners to set the reward expiration', async function () {
      const updatedSetRewardExpiration = 2;

      await this.mockRewardManager.setRewardExpiration(updatedSetRewardExpiration);
      assert.equal(await this.mockRewardManager.rewardExpiration(), updatedSetRewardExpiration);

      await this.mockRewardManager.setRewardExpiration(rewardExpiration);
      return assert.equal(await this.mockRewardManager.rewardExpiration(), rewardExpiration);
    });

    it('should allow owners to set the reward percentage for holders', async function () {
      const updatedSetRewardPercentage = 10;

      await this.mockRewardManager.setHolderRewardPercentage(updatedSetRewardPercentage);
      assert.equal(await this.mockRewardManager.holderRewardPercentage(), updatedSetRewardPercentage);

      await this.mockRewardManager.setHolderRewardPercentage(holderRewardPercentage);
      return assert.equal(await this.mockRewardManager.holderRewardPercentage(), holderRewardPercentage);
    });

    it('should mint AV tokens based on reward amount upon updating the bank epoch reward', async function () {
      // Setup our first seeder/holder
      const seedValue = new BigNumber(1000);
      await this.mockBank.seed(this.vaultInstance.address, {
        value: seedValue
      });

      // Fast-forward to the next epoch and call the reward updater
      await gotoNextEpoch(this);
      await this.mockRewardManager.updateRewardBalance();

      const currentTokenSupply = new BigNumber(await this.mockBank.totalSupply());

      // Again, fast-forward to the next epoch
      // This is due to the fact that golds coming from seeding won't be eligible for epoch rewards right away
      // and only until the next epoch where the votes are activated, the will be eligible
      await gotoNextEpoch(this);

      // Simulate epoch reward distribution by increasing the MockBank's lockedGold
      const epochReward = new BigNumber(100);
      await this.mockBank.mockEpochReward({ value: epochReward });

      // Update the reward for the latest epoch and confirm that the new tokens are minted
      // according to the amount allocated for the AV token holders
      await this.mockRewardManager.updateRewardBalance();

      const updatedTokenSupply = new BigNumber(await this.mockBank.totalSupply());
      const rewardPercentage = new BigNumber(await this.mockRewardManager.holderRewardPercentage());
      const holdersReward = epochReward.multipliedBy(rewardPercentage).dividedBy(100);
      return assert.equal(updatedTokenSupply.toFixed(0), currentTokenSupply.plus(holdersReward).toFixed(0));
    });

    it('should allow holders to claim available unclaimed rewards', async function () {
      // Temporarily set to only 1 last epoch
      await this.mockRewardManager.setRewardExpiration(1);

      const currentTokenBalance = new BigNumber(await this.mockBank.balanceOf(this.vaultInstance.address));

      // Since there's only 1 holder, it will receive 100% of rewards allocated for holders
      await this.mockRewardManager.claimReward(this.vaultInstance.address);

      // Confirm that the holder's token balance is correctly updated
      const epoch = new BigNumber(await this.mockRewardManager.getEpochNumber());
      const holdersReward = new BigNumber(await this.mockRewardManager.getEpochRewardBalance(epoch - 1));
      const updatedTokenBalance = new BigNumber(await this.mockBank.balanceOf(this.vaultInstance.address));
      return assert.equal(updatedTokenBalance.toFixed(0), currentTokenBalance.plus(holdersReward).toFixed(0));
    });
  });

  describe('Methods 🛑', function () {
    it('should not allow non-owners to set the reward expiration', async function () {
      return assert.isRejected(this.mockRewardManager.setRewardExpiration(2, { from: this.secondarySender }));
    });

    it('should not allow non-owners to set the reward percentage for holders', async function () {
      return assert.isRejected(this.mockRewardManager.setHolderRewardPercentage(5, { from: this.secondarySender }));
    });

    it('should not allow numbers less than "1" for the reward expiration', async function () {
      return assert.isRejected(this.mockRewardManager.setRewardExpiration(0));
    });

    it('should not allow numbers < 0 or > 99 for the reward percentage', async function () {
      await assert.isRejected(this.mockRewardManager.setHolderRewardPercentage(0));
      return assert.isRejected(this.mockRewardManager.setHolderRewardPercentage(100));
    });

    it('should not allow calling `updateRewardBalance` if already called on the same epoch', async function () {
      await this.mockRewardManager.setRewardExpiration(rewardExpiration);

      // Attempt to call the update method twice on the same epoch
      await gotoNextEpoch(this);
      await this.mockRewardManager.updateRewardBalance();

      return assert.isRejected(this.mockRewardManager.updateRewardBalance());
    });

    it('should not allow reward claiming if already claimed up to the last available epoch', async function () {
      // Attempt to claim reward twice on the same epoch
      await gotoNextEpoch(this);
      await this.mockRewardManager.claimReward(this.vaultInstance.address);

      return assert.isRejected(this.mockRewardManager.claimReward(this.vaultInstance.address));
    });
  });
});
