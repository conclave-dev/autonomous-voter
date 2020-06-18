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
      const manageableBalance = new BigNumber(await this.vaultInstance.getManageableBalance());
      const nonvotingBalance = new BigNumber(await this.vaultInstance.getNonvotingBalance());
      const deposit = 1;

      await this.vaultInstance.deposit({
        value: deposit
      });

      const newManageableBalance = new BigNumber(await this.vaultInstance.getManageableBalance());
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

  describe('VaultManagers', function () {
    it('should set a voting vault manager with setVotingVaultManager', async function () {
      await this.vaultInstance.setVotingVaultManager(this.vaultManagerInstance.address);

      const { 0: contractAddress, 1: rewardSharePercentage } = await this.vaultInstance.getVotingVaultManager();
      const vaultManagerRewardSharePercentage = new BigNumber(await this.vaultManagerInstance.rewardSharePercentage());

      assert.equal(
        contractAddress,
        this.vaultManagerInstance.address,
        `Voting manager address should be ${this.vaultManagerInstance.address}`
      );
      assert.equal(
        new BigNumber(rewardSharePercentage).toFixed(0),
        vaultManagerRewardSharePercentage.toFixed(0),
        `Reward share percentage should be ${vaultManagerRewardSharePercentage}`
      );
    });

    it('should remove the voting vault manager with removeVotingVaultManager', async function () {
      const votingVaultManagerBeforeRemoval = (await this.vaultInstance.getVotingVaultManager())[0];

      assert.equal(
        votingVaultManagerBeforeRemoval,
        this.vaultManagerInstance.address,
        'Voting vault manager incorrectly set'
      );

      await this.vaultInstance.removeVotingVaultManager();

      const votingVaultManagerAfterRemoval = (await this.vaultInstance.getVotingVaultManager())[0];

      assert.notEqual(
        votingVaultManagerAfterRemoval,
        this.vaultManagerInstance.address,
        'Voting vault manager was not removed'
      );
    });
  });

  describe('initiateWithdrawal(uint256 amount)', function () {
    it('should be able to initiate withdrawal', async function () {
      const currentBalance = new BigNumber(await this.vaultInstance.getNonvotingBalance());
      const withdrawAmount = new BigNumber('1e9');

      await this.vaultInstance.initiateWithdrawal(withdrawAmount.toString());

      assert.equal(
        new BigNumber(await this.vaultInstance.getNonvotingBalance()).toFixed(0),
        currentBalance.minus(withdrawAmount).toFixed(0),
        `Updated non-voting balance doesn't match after withdrawal`
      );
    });

    it('should not be able to initiate withdrawal with amount larger than owned non-voting golds', async function () {
      const withdrawAmount = new BigNumber('1e18');

      assert.isRejected(this.vaultInstance.initiateWithdrawal(withdrawAmount.toString()));
    });
  });

  describe('cancelWithdrawal(uint256 index, uint256 amount)', function () {
    it('should be able to initiate withdrawal and then cancel it', async function () {
      const currentBalance = new BigNumber(await this.vaultInstance.getNonvotingBalance());
      const withdrawAmount = new BigNumber('1e9');

      await this.vaultInstance.initiateWithdrawal(withdrawAmount.toString());
      await this.vaultInstance.cancelWithdrawal(0, withdrawAmount.toString());

      assert.equal(
        new BigNumber(await this.vaultInstance.getNonvotingBalance()).toFixed(0),
        currentBalance.toFixed(0),
        `Vault's non-voting balance shouldn't change after withdrawal cancellation`
      );
    });

    it('should not be able to cancel non-existent withdrawal', async function () {
      const withdrawAmount = new BigNumber('1e9');

      assert.isRejected(this.vaultInstance.cancelWithdrawal(withdrawAmount.toString()));
    });
  });

  describe('withdraw(uint256 index)', function () {
    it('should be able to withdraw after the unlocking period has passed', async function () {
      await this.mockVaultInstance.deposit({
        value: new BigNumber('1e10')
      });

      const currentBalance = new BigNumber(await this.mockVaultInstance.getNonvotingBalance());
      const withdrawAmount = new BigNumber('1e9');

      // Set the unlocking period to 0 second so that funds can be withdrawn immediately
      await this.mockLockedGold.setUnlockingPeriod(0);

      await this.mockVaultInstance.initiateWithdrawal(withdrawAmount.toString());
      await this.mockVaultInstance.withdraw(0);

      assert.equal(
        new BigNumber(await this.mockVaultInstance.getNonvotingBalance()).toFixed(0),
        currentBalance.minus(withdrawAmount).toFixed(0),
        `Updated non-voting balance doesn't match after withdrawal`
      );

      assert.equal(
        new BigNumber(await kit.web3.eth.getBalance(this.mockVaultInstance.address)).toFixed(0),
        withdrawAmount.toFixed(0),
        `Vault's main balance doesn't match the withdrawn amount`
      );
    });

    it('should not be able to withdraw before the unlocking period has passed', async function () {
      const withdrawAmount = new BigNumber('1e9');

      // Set the unlocking period to 1 day so that no funds are transfered to the Vault
      await this.mockLockedGold.setUnlockingPeriod(86400);

      await this.mockVaultInstance.initiateWithdrawal(withdrawAmount.toString());

      assert.isRejected(this.mockVaultInstance.withdraw(0));
    });
  });
});
