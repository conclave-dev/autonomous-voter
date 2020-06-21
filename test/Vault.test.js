const BigNumber = require('bignumber.js');
const { assert, kit } = require('./setup');
const { primarySenderAddress } = require('../config');

describe('Vault', function () {
  describe('initialize(address registry, address owner)', function () {
    it('should initialize with an owner and register a Celo account', async function () {
      const accounts = await kit.contracts.getAccounts();

      assert.equal(await this.vaultInstance.owner.call(), primarySenderAddress, 'Does not have owner set');
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

      assert.equal(
        newManageableBalance.toFixed(0),
        manageableBalance.plus(1).toFixed(0),
        'Manageable balance did not increase'
      );
      return assert.equal(
        newNonvotingBalance.toFixed(0),
        nonvotingBalance.plus(1).toFixed(0),
        'Nonvoting balance did not increase'
      );
    });
  });

  describe('Managers', function () {
    it('should set a voting vault manager with setVoteManager', async function () {
      await this.vaultInstance.setVoteManager(this.managerInstance.address);

      const { 0: contractAddress, 1: commission } = await this.vaultInstance.getVoteManager();
      const managerCommission = new BigNumber(await this.managerInstance.commission());

      assert.equal(
        contractAddress,
        this.managerInstance.address,
        `Voting manager address should be ${this.managerInstance.address}`
      );
      assert.equal(
        new BigNumber(commission).toFixed(0),
        managerCommission.toFixed(0),
        `Reward share percentage should be ${managerCommission}`
      );
    });

    it('should remove the voting vault manager with removeVoteManager', async function () {
      const voteManagerBeforeRemoval = (await this.vaultInstance.getVoteManager())[0];

      assert.equal(voteManagerBeforeRemoval, this.managerInstance.address, 'Voting vault manager incorrectly set');

      await this.vaultInstance.removeVoteManager();

      const voteManagerAfterRemoval = (await this.vaultInstance.getVoteManager())[0];

      assert.notEqual(voteManagerAfterRemoval, this.managerInstance.address, 'Voting vault manager was not removed');
    });
  });
});
