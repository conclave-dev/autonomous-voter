const { assert } = require('./setup');
const { time } = require('@openzeppelin/test-helpers');
const { default: BigNumber } = require('bignumber.js');
const { rewardExpiration, holderRewardPercentage } = require('../../config');

const gotoNextEpoch = async (test, skip = 1) => {
  await time.advanceBlockTo(
    new BigNumber(await test.kit.web3.eth.getBlockNumber()).plus(test.epochSize * skip).toFixed(0)
  );
};

describe.only('RewardManager', function () {
  before(async function () {
    await this.rewardManager.setBank(this.mockBank.address);
    this.lockedGold = (await this.kit._web3Contracts.getLockedGold()).methods;

    // Fast-forward to the next epoch
    this.epochSize = new BigNumber(await this.rewardManager.getEpochSize());
    await gotoNextEpoch(this);
  });

  after(async function () {
    await this.rewardManager.setBank(this.bank.address);
  });

  describe('State', function () {
    it('should have the correct reward expiration', async function () {
      return assert.equal(await this.rewardManager.rewardExpiration(), rewardExpiration);
    });

    it('should have the correct holder reward percentage', async function () {
      return assert.equal(await this.rewardManager.holderRewardPercentage(), holderRewardPercentage);
    });
  });

  describe('Methods ✅', function () {
    it('should allow owners to set the reward expiration', async function () {
      const updatedSetRewardExpiration = 2;

      await this.rewardManager.setRewardExpiration(updatedSetRewardExpiration);
      assert.equal(await this.rewardManager.rewardExpiration(), updatedSetRewardExpiration);

      await this.rewardManager.setRewardExpiration(rewardExpiration);
      return assert.equal(await this.rewardManager.rewardExpiration(), rewardExpiration);
    });

    it('should allow owners to set the reward percentage for holders', async function () {
      const updatedSetRewardPercentage = 10;

      await this.rewardManager.setHolderRewardPercentage(updatedSetRewardPercentage);
      assert.equal(await this.rewardManager.holderRewardPercentage(), updatedSetRewardPercentage);

      await this.rewardManager.setHolderRewardPercentage(holderRewardPercentage);
      return assert.equal(await this.rewardManager.holderRewardPercentage(), holderRewardPercentage);
    });

    it('should mint AV tokens based on reward amount upon updating the bank epoch reward', async function () {
      // Setup our first seeder/holder
      const seedValue = new BigNumber(1000);
      await this.mockBank.seed(this.vaultInstance.address, {
        value: seedValue
      });

      // Fast-forward to the next epoch and call the reward updater
      await gotoNextEpoch(this);
      await this.rewardManager.updateRewardBalance();

      const currentTokenSupply = new BigNumber(await this.mockBank.totalSupply());

      // Fast-forward to the next epoch
      await gotoNextEpoch(this);

      // Simulate epoch reward distribution by increasing the MockBank's lockedGold
      const epochReward = new BigNumber(100);
      await this.mockBank.mockEpochReward({ value: epochReward });

      // Update the reward for the latest epoch and confirm that the new tokens are minted
      // according to the amount allocated for the AV token holders
      await this.rewardManager.updateRewardBalance();

      const updatedTokenSupply = new BigNumber(await this.mockBank.totalSupply());
      const rewardPercentage = new BigNumber(await this.rewardManager.holderRewardPercentage());
      const holdersReward = epochReward.multipliedBy(rewardPercentage).dividedBy(100);
      return assert.equal(updatedTokenSupply.toFixed(0), currentTokenSupply.plus(holdersReward).toFixed(0));
    });

    it('should allow holders to claim available unclaimed rewards', async function () {
      // Temporarily set to only 1 last epoch
      await this.rewardManager.setRewardExpiration(1);

      const currentTokenBalance = new BigNumber(await this.mockBank.balanceOf(this.vaultInstance.address));

      // Since there's only 1 holder, it will receive 100% of rewards allocated for holders
      await this.rewardManager.claimReward(this.vaultInstance.address);

      const epoch = new BigNumber(await this.rewardManager.getEpochNumber());
      const holdersReward = new BigNumber(await this.rewardManager.getEpochRewardBalance(epoch - 1));
      const updatedTokenBalance = new BigNumber(await this.mockBank.balanceOf(this.vaultInstance.address));
      return assert.equal(updatedTokenBalance.toFixed(0), currentTokenBalance.plus(holdersReward).toFixed(0));
    });
  });
});
