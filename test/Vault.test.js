const { assert } = require('./setup');
const { default: BigNumber } = require('bignumber.js');

describe('Vault', function () {
  describe('State', function () {
    it('should have a proxy admin', async function () {
      return assert.equal(await this.vaultInstance.proxyAdmin(), this.proxyAdmin.address);
    });

    it('should have lockedGold', async function () {
      const lockedGold = await this.vaultInstance.lockedGold();
      const celoLockedGold = (await this.kit.contracts.getLockedGold()).address;

      return assert.equal(lockedGold, celoLockedGold);
    });

    it('should have a pending withdrawals linked list', async function () {
      const pendingWithdrawals = await this.vaultInstance.pendingWithdrawals();

      assert.property(pendingWithdrawals, 'head');
      assert.property(pendingWithdrawals, 'tail');
      return assert.property(pendingWithdrawals, 'numElements');
    });
  });

  describe('Methods ✅', function () {
    it('should allow its owner to set its proxy admin', function () {
      return assert.isFulfilled(this.vaultInstance.setProxyAdmin(this.proxyAdmin.address));
    });

    it('should return the vault nonvoting and voting balances', async function () {
      const balances = await this.vaultInstance.getBalances();
      const votingBalance = balances[0];
      const nonvotingBalance = balances[1];

      assert.isNumber(parseInt(votingBalance));
      return assert.isNumber(parseInt(nonvotingBalance));
    });

    it('should allow token deposits', async function () {
      const nonvotingBalanceBefore = new BigNumber((await this.vaultInstance.getBalances())[1]);

      await this.vaultInstance.deposit({ value: 1 });

      const nonvotingBalanceAfter = new BigNumber((await this.vaultInstance.getBalances())[1]);

      return assert.isTrue(nonvotingBalanceBefore.plus(1).isEqualTo(nonvotingBalanceAfter));
    });
  });

  describe('Methods 🛑', function () {
    it('should not allow a non-owner to set its proxy admin', function () {
      return assert.isRejected(
        this.vaultInstance.setProxyAdmin(this.proxyAdmin.address, { from: this.secondarySender })
      );
    });

    it('should not allow token deposits if the value is 0', function () {
      return assert.isRejected(this.vaultInstance.deposit({ value: 0 }));
    });
  });
});
