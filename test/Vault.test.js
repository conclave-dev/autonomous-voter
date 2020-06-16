const BigNumber = require('bignumber.js');
const { assert, expect, contracts, kit } = require('./setup');
const { primarySenderAddress, registryContractAddress } = require('../config');

describe('Vault', function () {
  before(async function () {
    await this.vaultFactory.createInstance(registryContractAddress, {
      value: new BigNumber('1e17')
    });

    const vault = (await this.archive.getVaultsByOwner(primarySenderAddress)).pop();
    const vaultManager = (await this.archive.getVaultManagersByOwner(primarySenderAddress)).pop();

    this.vaultInstance = await contracts.Vault.at(vault);
    this.vaultManagerInstance = await contracts.VaultManager.at(vaultManager);
  });

  describe('initialize(address registry, address owner)', function () {
    it('should initialize with an owner and register a Celo account', async function () {
      const accounts = await kit.contracts.getAccounts();

      assert.equal(await this.vaultInstance.owner(), primarySenderAddress, 'Does not have owner set');
      assert.equal(await accounts.isAccount(this.vaultInstance.address), true, 'Not a registered Celo account');
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
      assert.equal(
        newNonvotingBalance.toFixed(0),
        nonvotingBalance.plus(1).toFixed(0),
        'Nonvoting balance did not increase'
      );
    });
  });

  describe('VotingVaultManager', function () {
    it('should set a voting vault manager with setVotingVaultManager', async function () {
      await this.vaultInstance.setVotingVaultManager(this.vaultManagerInstance.address);

      const { 0: contractAddress, 1: rewardSharePercentage } = await this.vaultInstance.getVotingVaultManager();
      const vaultManagerRewardSharePercentage = new BigNumber(await this.vaultManagerInstance.rewardSharePercentage());
      const hasVault = await this.vaultManagerInstance.hasVault(this.vaultInstance.address);

      await expect(this.vaultInstance.setVotingVaultManager(this.vaultManagerInstance.address)).to.be.rejectedWith(
        Error
      );
      assert(
        contractAddress,
        this.vaultManagerInstance.address,
        `Voting manager address should be ${this.vaultManagerInstance.address}`
      );
      assert(
        new BigNumber(rewardSharePercentage).toFixed(0),
        vaultManagerRewardSharePercentage.toFixed(0),
        `Reward share percentage should be ${vaultManagerRewardSharePercentage}`
      );
      assert(hasVault, true, 'Vault was not registered with voting manager');
    });
  });
});
