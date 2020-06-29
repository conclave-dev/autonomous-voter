const BigNumber = require('bignumber.js');
const { assert } = require('./setup');

describe('Vault', function () {
  describe('initialize(address registry, address owner)', function () {
    it('should initialize with an owner and register a Celo account', async function () {
      const accounts = await this.kit.contracts.getAccounts();

      assert.equal(await this.vaultInstance.owner.call(), this.primarySender, 'Does not have owner set');
      return assert.equal(await accounts.isAccount(this.vaultInstance.address), true, 'Not a registered Celo account');
    });
  });

  describe('deposit()', function () {
    it('should enable owners to make deposits', async function () {
      const balances = await this.vaultInstance.getBalances();
      const balanceTotal = new BigNumber(balances[0]).plus(new BigNumber(balances[1]));
      const deposit = 1;

      await this.vaultInstance.deposit({
        value: deposit
      });

      const newBalances = await this.vaultInstance.getBalances();
      const newBalanceTotal = new BigNumber(newBalances[0]).plus(new BigNumber(newBalances[1]));

      return assert.isTrue(
        newBalanceTotal.isEqualTo(balanceTotal.plus(deposit)),
        'Manageable balance did not increase'
      );
    });
  });

  describe('withdrawals', function () {
    it('should initiate a withdrawal without revoking votes if the nonvoting balance is sufficient', async function () {
      const balances = await this.vaultInstance.getBalances();
      const votingBeforeWithdrawal = new BigNumber(balances[0]);
      const nonvotingBeforeWithdrawal = new BigNumber(balances[1]);
      const withdrawalAmount = nonvotingBeforeWithdrawal.dividedBy(10).toFixed(0);

      await this.vaultInstance.initiateWithdrawal(withdrawalAmount);

      const postWithdrawalBalances = await this.vaultInstance.getBalances();
      const votingAfterWithdrawal = new BigNumber(postWithdrawalBalances[0]);
      const nonvotingAfterWithdrawal = new BigNumber(postWithdrawalBalances[1]);

      assert.isTrue(
        votingBeforeWithdrawal.isEqualTo(votingAfterWithdrawal),
        `Voting balance should not be drawn from if the nonvoting balance is sufficient`
      );
      return assert.isTrue(
        nonvotingBeforeWithdrawal.minus(withdrawalAmount).isEqualTo(nonvotingAfterWithdrawal),
        `Updated non-voting balance doesn't match after withdrawal`
      );
    });

    it('should not initiate withdrawal with an amount larger than the total balance', async function () {
      const balances = await this.vaultInstance.getBalances();
      const totalBalance = new BigNumber(balances[0]).plus(new BigNumber(balances[1]));
      const invalidWithdrawalAmount = totalBalance.plus(1).toFixed(0);

      assert.isRejected(this.vaultInstance.initiateWithdrawal(invalidWithdrawalAmount));
    });
  });

  describe('Managers', function () {
    it('should set a vote manager with setVoteManager', async function () {
      const manager = await this.vaultInstance.manager();

      if (manager !== this.managerInstance.address) {
        await this.vaultInstance.setVoteManager(this.managerInstance.address);
      }

      const managerCommission = new BigNumber(await this.vaultInstance.managerCommission());

      assert.equal(
        await this.vaultInstance.manager(),
        this.managerInstance.address,
        `Vote manager address should be ${this.managerInstance.address}`
      );
      return assert.isTrue(
        managerCommission.isEqualTo(managerCommission),
        `Manager commission should be ${managerCommission}`
      );
    });

    it('should remove the vote manager with removeVoteManager', async function () {
      const managerBeforeRemoval = await this.vaultInstance.manager();

      assert.equal(managerBeforeRemoval, this.managerInstance.address, 'Vote manager incorrectly set');

      await this.vaultInstance.removeVoteManager();

      const managerAfterRemoval = await this.vaultInstance.manager();

      return assert.notEqual(managerAfterRemoval, this.managerInstance.address, 'Vote manager was not removed');
    });
  });
});
