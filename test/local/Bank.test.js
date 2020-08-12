const { assert } = require('./setup');
const { tokenName, tokenSymbol, tokenDecimal, seedCapacity, seedRatio } = require('../../config');

describe.only('Bank', function () {
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
      const preSeedBalance = (await this.bank.balanceOf(this.vaultInstance.address)).toNumber();
      const seedValue = 1;

      await this.bank.seed(this.vaultInstance.address, {
        value: preSeedBalance + seedValue
      });

      const postSeedBalance = (await this.bank.balanceOf(this.vaultInstance.address)).toNumber();

      return assert.equal(preSeedBalance + seedValue, postSeedBalance);
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
  });
});
