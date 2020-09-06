const { assert } = require('./setup');
const { time } = require('@openzeppelin/test-helpers');
const { default: BigNumber } = require('bignumber.js');
const { tokenName, tokenSymbol, tokenDecimal, seedCapacity, seedRatio } = require('../../config');

describe('Bank', function () {
  before(async function () {
    this.accounts = (await this.kit._web3Contracts.getAccounts()).methods;
    this.lockedGold = (await this.kit._web3Contracts.getLockedGold()).methods;
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

    it('should have the correct initial frozen balance for non-holders', async function () {
      return assert.equal(await this.bank.frozenBalanceOf(this.bank.address), 0);
    });

    it('should have a valid seed freeze duration', async function () {
      return assert.isAbove((await this.bank.seedFreezeDuration()).toNumber(), 1);
    });

    it('should be a registered CELO account', async function () {
      return assert.isTrue(await (await this.accounts.isAccount(this.bank.address)).call());
    });
  });

  describe('Methods ✅', function () {
    it('should allow owners to set the seed freeze duration', async function () {
      const currentSeedFreezeDuration = await this.bank.seedFreezeDuration();
      const updatedSeedFreezeDuration = currentSeedFreezeDuration * 2;

      await this.bank.setSeedFreezeDuration(updatedSeedFreezeDuration);
      return assert.equal(await this.bank.seedFreezeDuration(), updatedSeedFreezeDuration);
    });

    it('should allow an owner of a vault to seed tokens, update its frozen balance, and update total CELO locked in Bank', async function () {
      const preSeedLockedGold = new BigNumber(
        (await await this.lockedGold.getAccountTotalLockedGold(this.bank.address)).call()
      );
      const preSeedBalance = new BigNumber(await this.bank.balanceOf(this.vaultInstance.address));
      const preSeedFrozenBalance = new BigNumber(await this.bank.frozenBalanceOf(this.vaultInstance.address));
      const seedRatio = new BigNumber(await this.bank.seedRatio());
      const seedValue = new BigNumber(1);

      await this.bank.seed(this.vaultInstance.address, {
        value: seedValue
      });

      const postSeedLockedGold = new BigNumber(
        (await await this.lockedGold.getAccountTotalLockedGold(this.bank.address)).call()
      );
      const postSeedBalance = new BigNumber(await this.bank.balanceOf(this.vaultInstance.address));
      const postSeedFrozenBalance = new BigNumber(await this.bank.frozenBalanceOf(this.vaultInstance.address));
      const convertedSeedValue = seedValue.multipliedBy(seedRatio);

      assert.equal(preSeedLockedGold.plus(convertedSeedValue).toFixed(0), postSeedLockedGold.toFixed(0));

      assert.equal(
        preSeedFrozenBalance.plus(seedValue.multipliedBy(seedRatio)).toFixed(0),
        postSeedFrozenBalance.toFixed(0)
      );

      return assert.equal(
        preSeedBalance.plus(seedValue.multipliedBy(seedRatio)).toFixed(0),
        postSeedBalance.toFixed(0)
      );
    });

    it('should return the correct details and number of frozen token records of an account', async function () {
      // Since at this point, the test vault should only have 1 frozen token record, the amount of the first record
      // shold be equal to the total frozen balance it has
      const frozenBalance = new BigNumber(await this.bank.frozenBalanceOf(this.vaultInstance.address));
      const totalRecords = new BigNumber(await this.bank.getFrozenTokenCount(this.vaultInstance.address));
      const { 0: amount } = await this.bank.getFrozenTokenDetail(this.vaultInstance.address, 0);

      assert.equal(new BigNumber(amount).toFixed(0), frozenBalance.toFixed(0));
      return assert.equal(totalRecords.toFixed(0), 1);
    });

    it('should allow an owner of a vault to unfreeze tokens when available', async function () {
      // Set the frozen duration to a small value so we can fast-forward slightly to get them unfrozen
      await this.bank.setSeedFreezeDuration(1);

      const previousFrozenBalance = new BigNumber(await this.bank.frozenBalanceOf(this.vaultInstance.address));
      const seedValue = new BigNumber(1);

      await this.bank.seed(this.vaultInstance.address, {
        value: seedValue
      });

      // Fast-forward 1 block
      await time.advanceBlockTo((await this.kit.web3.eth.getBlockNumber()) + 100);

      // Attempt to unfreeze the second record, which should be unfrozen due to the short freeze duration
      await this.bank.unfreezeTokens(this.vaultInstance.address, 1);

      const currentFrozenBalance = new BigNumber(await this.bank.frozenBalanceOf(this.vaultInstance.address));

      return assert.equal(currentFrozenBalance.toFixed(0), previousFrozenBalance.toFixed(0));
    });

    it('should allow an owner of a vault to transfer unfrozen tokens', async function () {
      const previousTargetBalance = new BigNumber(await this.bank.balanceOf(this.secondarySender));
      const amount = new BigNumber(1);

      await this.bank.transferFromVault(this.vaultInstance.address, this.secondarySender, amount.toString());

      // Confirm the balances of the transfer target
      return assert.equal(
        new BigNumber(await this.bank.balanceOf(this.secondarySender)).toFixed(0),
        previousTargetBalance.plus(amount).toFixed(0)
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

    it('should not allow a owners to unfreeze tokens when not yet available', function () {
      // Attempt to unfreeze the first record, which should not be unfrozen yet
      return assert.isRejected(this.bank.unfreezeTokens(this.vaultInstance.address, 0));
    });
  });
});
