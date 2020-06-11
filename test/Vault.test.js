const BigNumber = require('bignumber.js');
const { assert, expect, contracts, kit } = require('./setup');
const { primarySenderAddress, registryContractAddress } = require('../config');

describe('Vault', () => {
  before(async () => {
    this.archive = await contracts.Archive.deployed();

    await (await contracts.VaultFactory.deployed()).createInstance(registryContractAddress, {
      value: new BigNumber('1e17')
    });

    this.vault = await contracts.Vault.at(await this.archive.getVault(primarySenderAddress));
  });

  describe('initialize(address registry, address owner)', () => {
    it('should initialize with an owner and register a Celo account', async () => {
      const accounts = await kit.contracts.getAccounts();

      assert.equal(await this.vault.owner(), primarySenderAddress, 'Does not have owner set');
      assert.equal(await accounts.isAccount(this.vault.address), true, 'Not a registered Celo account');
    });
  });

  describe('deposit()', () => {
    it('should enable owners to make deposits', async () => {
      const manageableBalance = new BigNumber(await this.vault.getManageableBalance());
      const nonvotingBalance = new BigNumber(await this.vault.getNonvotingBalance());
      const deposit = 1;

      await this.vault.deposit({
        value: deposit
      });

      const newManageableBalance = new BigNumber(await this.vault.getManageableBalance());
      const newNonvotingBalance = new BigNumber(await this.vault.getNonvotingBalance());

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

  describe('setVotingManager(Strategy strategy)', () => {
    it('should set a voting manager', async () => {
      // Start by creating the test strategy instance
      await (await contracts.StrategyFactory.deployed()).createInstance(
        this.archive.address,
        primarySenderAddress,
        '10',
        new BigNumber('1e16').toString()
      );

      // Test adding managedGold to a strategy
      const strategy = await contracts.Strategy.at(await this.archive.getStrategy(primarySenderAddress));

      await this.vault.setVotingManager(strategy.address);

      const { 0: contractAddress, 1: rewardSharePercentage } = await this.vault.getVotingManager();
      const strategyRewardSharePercentage = new BigNumber(await strategy.rewardSharePercentage());
      const hasVault = await strategy.hasVault(this.vault.address);

      await expect(this.vault.setVotingManager(strategy.address)).to.be.rejectedWith(Error);
      assert(contractAddress, strategy.address, `Voting manager address should be ${strategy.address}`);
      assert(
        new BigNumber(rewardSharePercentage).toFixed(0),
        strategyRewardSharePercentage.toFixed(0),
        `Reward share percentage should be ${strategyRewardSharePercentage}`
      );
      assert(hasVault, true, 'Vault was not registered with voting manager');
    });
  });
});
