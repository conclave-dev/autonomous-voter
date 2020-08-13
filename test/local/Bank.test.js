const { assert } = require('./setup');
const { time } = require('@openzeppelin/test-helpers');
const { default: BigNumber } = require('bignumber.js');
const { tokenName, tokenSymbol, tokenDecimal, seedCapacity, seedRatio, seedFreezeDuration } = require('../../config');

describe('Bank', function () {
  after(async function () {
    // Always reset the seedFreezeDuration to the originally intended value
    await this.bank.setSeedFreezeDuration(new BigNumber(seedFreezeDuration).toString());
  });

  describe('State', function () {
    it('should have a valid token name', async function () {
      return assert.equal(await this.bank.name(), tokenName);
    });

    it('should have a valid token symbol', async function () {
      return assert.equal(await this.bank.symbol(), tokenSymbol);
    });

    it('should have a valid token decimal', async function () {
      return assert.equal(await this.bank.decimals(), tokenDecimal);
    });

    it('should have the correct initial balance for non-holders', async function () {
      return assert.equal(await this.bank.balanceOf(this.bank.address), 0);
    });

    it('should have a valid seed capacity', async function () {
      return assert.equal(await this.bank.seedCapacity(), seedCapacity);
    });

    it('should have a valid seed ratio', async function () {
      return assert.equal(await this.bank.seedRatio(), seedRatio);
    });

    it('should have a valid seed freeze duration', async function () {
      return assert.isAbove((await this.bank.seedFreezeDuration()).toNumber(), 1);
    });
  });

  describe('Methods ✅', function () {
    it('should allow owners to set the seed freeze duration', async function () {
      const currentSeedFreezeDuration = await this.bank.seedFreezeDuration();
      const updatedSeedFreezeDuration = currentSeedFreezeDuration * 2;

      await this.bank.setSeedFreezeDuration(updatedSeedFreezeDuration);
      return assert.equal(await this.bank.seedFreezeDuration(), updatedSeedFreezeDuration);
    });

    it('should allow an owner of a vault to seed tokens', async function () {
      const preSeedBalance = new BigNumber(await this.bank.balanceOf(this.vaultInstance.address));
      const preSeedFrozenBalance = new BigNumber(await this.bank.getFrozenTokens(this.vaultInstance.address));
      const seedRatio = new BigNumber(await this.bank.seedRatio());
      const seedValue = new BigNumber(1);

      await this.bank.seed(this.vaultInstance.address, {
        value: seedValue
      });

      const postSeedBalance = new BigNumber(await this.bank.balanceOf(this.vaultInstance.address));
      const postSeedFrozenBalance = new BigNumber(await this.bank.getFrozenTokens(this.vaultInstance.address));

      assert.equal(
        preSeedFrozenBalance.plus(seedValue.multipliedBy(seedRatio)).toFixed(0),
        postSeedFrozenBalance.toFixed(0)
      );

      return assert.equal(
        preSeedBalance.plus(seedValue.multipliedBy(seedRatio)).toFixed(0),
        postSeedBalance.toFixed(0)
      );
    });

    it('should allow an owner of a vault to lock its balance', async function () {
      const vaultBalance = (await this.bank.balanceOf(this.vaultInstance.address)).toNumber();
      const lockCycle = 1;

      await this.bank.lock(this.vaultInstance.address, lockCycle);

      const { 0: amount, 1: cycle } = await this.bank.getLockedTokens(this.vaultInstance.address);

      assert.equal(cycle.toNumber(), lockCycle);
      return assert.equal(amount.toNumber(), vaultBalance);
    });

    it('should allow an owner of a vault to unlock its balance', async function () {
      const vaultBalance = (await this.bank.balanceOf(this.vaultInstance.address)).toNumber();

      await this.bank.unlock(this.vaultInstance.address);

      const { 0: amount, 1: cycle } = await this.bank.getLockedTokens(this.vaultInstance.address);

      assert.isAtLeast(vaultBalance, 1);
      assert.equal(cycle.toNumber(), 0);
      return assert.equal(amount.toNumber(), 0);
    });

    it('should allow an owner of a vault to transfer unlocked (and unfrozen) tokens', async function () {
      // Set the frozen duration to a small value so we can fast-forward slightly to get them unfrozen
      await this.bank.setSeedFreezeDuration(1);

      const preSeedTargetBalance = new BigNumber(await this.bank.balanceOf(this.secondarySender));
      const preSeedFrozenBalance = new BigNumber(await this.bank.getFrozenTokens(this.vaultInstance.address));
      const seedValue = new BigNumber(1);

      await this.bank.seed(this.vaultInstance.address, {
        value: seedValue
      });

      // Fast-forward 1 block
      await time.advanceBlockTo((await this.kit.web3.eth.getBlockNumber()) + 100);

      // Make sure that the last seeded tokens are already unfrozen
      assert.equal(
        new BigNumber(await this.bank.getFrozenTokens(this.vaultInstance.address)).toFixed(0),
        preSeedFrozenBalance.toFixed(0)
      );

      await this.bank.transferFromVault(this.vaultInstance.address, this.secondarySender, seedValue.toString());

      // Confirm the balances of both the vault and the transfer target
      assert.equal(
        new BigNumber(await this.bank.balanceOf(this.vaultInstance.address)).toFixed(0),
        preSeedFrozenBalance.toFixed(0)
      );

      return assert.equal(
        new BigNumber(await this.bank.balanceOf(this.secondarySender)).toFixed(0),
        preSeedTargetBalance.plus(seedValue).toFixed(0)
      );
    });
  });

  describe('Methods 🛑', function () {
    it('should not allow non-owners to set the seed freeze duration', function () {
      return assert.isRejected(
        this.bank.setSeedFreezeDuration(1, {
          from: this.secondarySender
        })
      );
    });

    it('should not allow zero to be set as the seed freeze duration', function () {
      return assert.isRejected(this.bank.setSeedFreezeDuration(0));
    });

    it('should not allow a non-owner of a vault to seed tokens', function () {
      return assert.isRejected(
        this.bank.seed(this.vaultInstance.address, {
          value: 1,
          from: this.secondarySender
        })
      );
    });

    it('should not allow a non-owner of a vault to lock tokens', function () {
      return assert.isRejected(
        this.bank.lock(this.vaultInstance.address, 1, {
          from: this.secondarySender
        })
      );
    });

    it('should not allow a non-owner of a vault to unlock tokens', function () {
      return assert.isRejected(
        this.bank.unlock(this.vaultInstance.address, {
          from: this.secondarySender
        })
      );
    });

    it('should not allow owners to perform transfer on locked and/or frozen tokens', async function () {
      // Attempt to transfer the entire unlocked balance of a vault including the newly minted (and frozen) tokens
      const balance = new BigNumber(await this.bank.balanceOf(this.vaultInstance.address));
      const { 0: amount } = await this.bank.getLockedTokens(this.vaultInstance.address);
      const unlockedBalance = balance.plus(new BigNumber(amount));

      return assert.isRejected(
        this.bank.transferFromVault(this.vaultInstance.address, this.secondarySender, unlockedBalance.toString())
      );
    });
  });
});
