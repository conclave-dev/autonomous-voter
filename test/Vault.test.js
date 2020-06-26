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
      const manageableBalance = new BigNumber(await this.vaultInstance.getLockedBalance());
      const nonvotingBalance = new BigNumber(await this.vaultInstance.getNonvotingBalance());
      const deposit = 1;

      await this.vaultInstance.deposit({
        value: deposit
      });

      const newManageableBalance = new BigNumber(await this.vaultInstance.getLockedBalance());
      const newNonvotingBalance = new BigNumber(await this.vaultInstance.getNonvotingBalance());

      assert.isTrue(newManageableBalance.isEqualTo(manageableBalance.plus(1)), 'Manageable balance did not increase');
      return assert.isTrue(
        newNonvotingBalance.isEqualTo(nonvotingBalance.plus(1)),
        'Nonvoting balance did not increase'
      );
    });
  });

  describe('Managers', function () {
    it('should set a vote manager with setVoteManager', async function () {
      await this.vaultInstance.setVoteManager(this.managerInstance.address);

      const { 0: contractAddress, 1: commission } = await this.vaultInstance.getVoteManager();
      const managerCommission = new BigNumber(await this.managerInstance.commission());

      assert.equal(
        contractAddress,
        this.managerInstance.address,
        `Vote manager address should be ${this.managerInstance.address}`
      );
      return assert.isTrue(
        new BigNumber(commission).isEqualTo(managerCommission),
        `Manager commission should be ${managerCommission}`
      );
    });

    it('should remove the vote manager with removeVoteManager', async function () {
      const voteManagerBeforeRemoval = (await this.vaultInstance.getVoteManager())[0];

      assert.equal(voteManagerBeforeRemoval, this.managerInstance.address, 'Vote manager incorrectly set');

      await this.vaultInstance.removeVoteManager();

      const voteManagerAfterRemoval = (await this.vaultInstance.getVoteManager())[0];

      return assert.notEqual(voteManagerAfterRemoval, this.managerInstance.address, 'Vote manager was not removed');
    });
  });
});
