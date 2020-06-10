const BigNumber = require('bignumber.js');
const { assert, expect, contracts, kit } = require('./setup');
const { primarySenderAddress, secondarySenderAddress, registryContractAddress } = require('../config');

describe('Vault', () => {
  before(async () => {
    this.archive = await contracts.Archive.deployed();

    await (await contracts.VaultFactory.deployed()).createInstance(
      registryContractAddress,
      this.archive.address,
      primarySenderAddress,
      {
        value: new BigNumber('1e17')
      }
    );

    this.vault = await contracts.Vault.at(await this.archive.getVault(primarySenderAddress));
  });

  describe('initializeVault(address registry, address owner)', () => {
    it('should initialize with an owner and register a Celo account', async () => {
      const accounts = await kit.contracts.getAccounts();

      assert.equal(await this.vault.owner(), primarySenderAddress, 'Does not have owner set');
      assert.equal(await accounts.isAccount(this.vault.address), true, 'Not a registered Celo account');
    });
  });

  describe('deposit()', () => {
    it('should enable owners to make deposits', async () => {
      const deposits = new BigNumber(await this.vault.unmanagedGold());
      const newDeposit = 1;

      await this.vault.deposit({
        value: newDeposit
      });

      assert.equal(
        new BigNumber(await this.vault.unmanagedGold()).toFixed(0),
        deposits.plus(newDeposit).toFixed(0),
        'Deposits did not increase'
      );
    });

    it('should not be able to deposit from a non-owner account', async () => {
      await expect(
        this.vault.deposit({
          from: secondarySenderAddress,
          value: 1
        })
      ).to.be.rejectedWith(Error);
    });
  });

  describe('addManagedGold(address strategyAddress, uint256 amount)', () => {
    it('should set the specified amount of managedGold to be registered under the specified strategy', async () => {
      // Start by creating the test strategy instance
      this.rewardSharePercentage = '10';
      this.minimumManagedGold = new BigNumber('1e16').toString();

      await (await contracts.StrategyFactory.deployed()).createInstance(
        this.archive.address,
        primarySenderAddress,
        this.rewardSharePercentage,
        this.minimumManagedGold
      );

      // Test adding managedGold to a strategy
      const strategyAddress = await this.archive.getStrategy(primarySenderAddress);
      const strategy = await contracts.Strategy.at(strategyAddress);
      const managedGoldAmount = new BigNumber('2e16');
      const initialUnmanagedGold = new BigNumber(await this.vault.unmanagedGold());

      await this.vault.addManagedGold(strategyAddress, managedGoldAmount.toString());

      // Also check the recorded entry for managedGold
      const firstManagedGold = await this.vault.managedGold(0);

      assert.equal(
        (await this.vault.unmanagedGold()).toString(),
        initialUnmanagedGold.minus(managedGoldAmount).toString(),
        'Invalid resulting unmanagedGold amount'
      );

      assert.equal(firstManagedGold.strategyAddress, strategyAddress, 'Invalid resulting strategy address');
      assert.equal(
        new BigNumber(firstManagedGold.amount).toString(),
        managedGoldAmount.toString(),
        'Invalid resulting managedGold amount'
      );
      assert.equal(
        await strategy.managedGold(this.vault.address, 0),
        managedGoldAmount.toString(),
        'Invalid resulting managedGold amount'
      );
    });
  });
});
