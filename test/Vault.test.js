const BigNumber = require('bignumber.js');
const { assert, kit } = require('./setup');
const { primarySenderAddress } = require('../config');

describe('Vault', function () {
  describe('initialize(address registry, address owner)', function () {
    it('should initialize with an owner and register a Celo account', async function () {
      const accounts = await kit.contracts.getAccounts();

      assert.equal(await this.vaultInstance.owner(), primarySenderAddress, 'Does not have owner set');
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

  describe('VotingVaultManager', function () {
    it('should set a voting vault manager with setVotingVaultManager', async function () {
      await this.vaultInstance.setVotingVaultManager(this.vaultManagerInstance.address);

      const { 0: contractAddress, 1: rewardSharePercentage } = await this.vault.getVotingVaultManager();
      const vaultManagerRewardSharePercentage = new BigNumber(await this.vaultManager.rewardSharePercentage());

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

    it('should remove the voting vault manager with removeVotingVaultManager', async () => {
      const votingVaultManagerBeforeRemoval = (await this.vault.getVotingVaultManager())[0];

      assert.equal(votingVaultManagerBeforeRemoval, this.vaultManager.address, 'Voting vault manager incorrectly set');

      await this.vault.removeVotingVaultManager();

      const votingVaultManagerAfterRemoval = (await this.vault.getVotingVaultManager())[0];

      assert.notEqual(
        votingVaultManagerAfterRemoval,
        this.vaultManager.address,
        'Voting vault manager was not removed'
      );
    });
  });
});
