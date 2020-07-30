const { assert } = require('./setup');
const { default: BigNumber } = require('bignumber.js');
const { localPrimaryAccount, localSecondaryAccount, tokenName, tokenSymbol, tokenDecimal } = require('../../config');
const { time } = require('@openzeppelin/test-helpers');

describe('Bank', function () {
  describe('State', function () {
    it('should have a valid token name', async function () {
      return assert.equal(await this.mockBank.name(), tokenName);
    });

    it('should have a valid token symbol', async function () {
      return assert.equal(await this.mockBank.symbol(), tokenSymbol);
    });

    it('should have a valid token decimal', async function () {
      return assert.equal(await this.mockBank.decimals(), tokenDecimal);
    });

    it('should have the correct initial balance for non-holders', async function () {
      return assert.equal(await this.mockBank.balanceOf(this.mockBank.address), 0);
    });

    it('should have a valid initial cycle epoch', async function () {
      return assert.equal(await this.mockBank.initialCycleEpoch(), 0);
    });
  });

  describe('Methods ✅', function () {
    it('should allow admin/owner to start the VM cycle', async function () {
      await this.mockBank.start();
      return assert.notEqual(new BigNumber(await this.mockBank.initialCycleEpoch()).toFixed(0), '0');
    });

    it('should mint tokens to contributors with valid contribution amount', async function () {
      const initialBalance = new BigNumber(await this.mockBank.balanceOf(localPrimaryAccount));
      const amount = new BigNumber(10).multipliedBy(this.tokenAmountMultiplier);
      await this.mockBank.seed({ from: localPrimaryAccount, value: amount });

      return assert.equal(
        new BigNumber(await this.mockBank.balanceOf(localPrimaryAccount)).toFixed(0),
        initialBalance.plus(amount).toFixed(0)
      );
    });

    it('should allow holders (owning tokens) to lock tokens', async function () {
      // For our local network setup, 1 epoch lasts for 100 blocks
      // Since locking can only be done after the first cycle has started,
      // which is 7 epochs after the call to `start`,
      // we need to fast forward 7 epochs (1 cycle)
      await time.advanceBlockTo((await this.kit.web3.eth.getBlockNumber()) + 700);

      const amount = new BigNumber(1).multipliedBy(this.tokenAmountMultiplier);
      await this.mockBank.lock(amount);
      const lockedToken = await this.mockBank.getAccountLockedToken(localPrimaryAccount);

      return assert.equal(new BigNumber(lockedToken[0]).toFixed(0), amount.toFixed(0));
    });

    it('should allow holders to lock additional tokens within locked period', async function () {
      const previousLockedToken = await this.mockBank.getAccountLockedToken(localPrimaryAccount);
      const previousAmount = new BigNumber(previousLockedToken[0]);
      const amount = new BigNumber(1).multipliedBy(this.tokenAmountMultiplier);
      await this.mockBank.lock(amount);
      const lockedToken = await this.mockBank.getAccountLockedToken(localPrimaryAccount);

      return assert.equal(new BigNumber(lockedToken[0]).toFixed(0), previousAmount.plus(amount).toFixed(0));
    });

    it('should allow holders to unlock tokens if unlockable', async function () {
      // In order to test successful unlock, we need to fast forward 14 epochs (2 cycles) for guaranteed unlock
      await time.advanceBlockTo((await this.kit.web3.eth.getBlockNumber()) + 1400);

      await this.mockBank.unlock();
      const lockedToken = await this.mockBank.getAccountLockedToken(localPrimaryAccount);

      return assert.equal(new BigNumber(lockedToken[0]).toFixed(0), 0);
    });
  });

  describe('Methods 🛑', function () {
    it('should not allow admin/owner to start the cycle again if already started', async function () {
      return assert.isRejected(this.mockBank.start());
    });

    it('should not mint tokens to contributors with invalid contribution amount', async function () {
      return assert.isRejected(this.mockBank.seed({ from: localPrimaryAccount, value: 0 }));
    });

    it('should not allow non-holders (no tokens owned) to lock tokens', async function () {
      const amount = new BigNumber(1).multipliedBy(this.tokenAmountMultiplier);
      return assert.isRejected(this.mockBank.lock(amount, { from: localSecondaryAccount }));
    });

    it('should not allow holders to lock tokens exceeding owned unlocked tokens', async function () {
      const unlockedBalance = new BigNumber(await this.mockBank.getAccountUnlockedBalance(localPrimaryAccount));
      const amount = unlockedBalance.plus(1).multipliedBy(this.tokenAmountMultiplier);
      return assert.isRejected(this.mockBank.lock(amount, { from: localSecondaryAccount }));
    });

    it('should not allow holders to unlock tokens if not yet unlockable', async function () {
      const amount = new BigNumber(1).multipliedBy(this.tokenAmountMultiplier);
      await this.mockBank.lock(amount);
      return assert.isRejected(this.mockBank.unlock());
    });

    it('should not allow holders to lock tokens if there are available unlockable tokens', async function () {
      // Skip few cycles to make the tokens to be unlockable
      await time.advanceBlockTo((await this.kit.web3.eth.getBlockNumber()) + 1400);

      const amount = new BigNumber(1).multipliedBy(this.tokenAmountMultiplier);
      return assert.isRejected(this.mockBank.lock(amount, { from: localSecondaryAccount }));
    });
  });
});
