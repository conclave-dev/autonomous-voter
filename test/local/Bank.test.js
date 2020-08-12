const { assert } = require('./setup');
const { tokenName, tokenSymbol, tokenDecimal, seedCapacity, seedRatio } = require('../../config');

describe('Bank', function () {
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
  });
});
