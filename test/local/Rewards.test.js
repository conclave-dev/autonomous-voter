const { assert } = require('./setup');

describe('Rewards', function () {
  describe('State', function () {
    it('should be a registered Celo account', async function () {
      const accounts = await this.kit.contracts.getAccounts();

      return assert.isTrue(await accounts.isAccount(this.rewards.address));
    });

    it('should have the Portfolio set', async function () {
      return assert.equal(await this.rewards.portfolio(), this.portfolio.address);
    });
  });

  describe('Methods ✅', function () {
    it('should enable the Bank to deposit and lock CELO', async function () {
      const lockedGold = await this.kit.contracts.getLockedGold();
      const seedAmount = 100;
      const lockedGoldBeforeSeed = (await lockedGold.getAccountTotalLockedGold(this.rewards.address)).toNumber();

      await this.bank.seed(this.vaultInstance.address, {
        value: seedAmount
      });

      const lockedGoldAfterSeed = (await lockedGold.getAccountTotalLockedGold(this.rewards.address)).toNumber();

      return assert.equal(lockedGoldBeforeSeed + seedAmount, lockedGoldAfterSeed);
    });
  });

  describe('Methods 🛑', function () {
    // it('should not allow a non-owner to set its proxy admin', function () {
    //   return assert.isRejected(
    //     this.vaultInstance.setProxyAdmin(this.proxyAdmin.address, { from: this.secondarySender })
    //   );
    // });
  });
});
