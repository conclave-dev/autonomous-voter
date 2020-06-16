const BigNumber = require('bignumber.js');
const { assert, expect, contracts, kit } = require('./setup');
const { primarySenderAddress, registryContractAddress } = require('../config');

describe('Vault', () => {
  before(async () => {
    this.app = await contracts.App.deployed();
    this.archive = await contracts.Archive.deployed();
    this.mockVaultImplementation = await contracts.MockVault.deployed();
    this.vaultImplementation = await contracts.Vault.deployed();
    this.mockLockedGold = await contracts.MockLockedGold.deployed();

    // Create the mocked vault instance
    await this.app.setContractImplementation('Vault', this.mockVaultImplementation.address);
    await (await contracts.VaultFactory.deployed()).createInstance(registryContractAddress, {
      value: new BigNumber('1e17')
    });

    let vaults = await this.archive.getVaultsByOwner(primarySenderAddress);
    this.mockVault = await contracts.MockVault.at(vaults[vaults.length - 1]);

    await this.mockLockedGold.reset();

    // Set the address of the mocked Celo contracts
    await this.mockVault.setMockContract(this.mockLockedGold.address, 'LockedGold');

    // Create the vault instance
    await this.app.setContractImplementation('Vault', this.vaultImplementation.address);
    await (await contracts.VaultFactory.deployed()).createInstance(registryContractAddress, {
      value: new BigNumber('1e17')
    });

    vaults = await this.archive.getVaultsByOwner(primarySenderAddress);
    this.vault = await contracts.Vault.at(vaults[vaults.length - 1]);
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

  describe('setVotingVaultManager(VaultManager vaultManager)', () => {
    it('should set a voting manager', async () => {
      // Start by creating the test vaultManager instance
      await (await contracts.VaultManagerFactory.deployed()).createInstance('10', new BigNumber('1e16').toString());

      // Test adding managedGold to a vaultManager
      const vaultManagers = await this.archive.getVaultManagersByOwner(primarySenderAddress);
      const vaultManager = await contracts.VaultManager.at(vaultManagers[vaultManagers.length - 1]);

      await this.vault.setVotingVaultManager(vaultManager.address);

      const { 0: contractAddress, 1: rewardSharePercentage } = await this.vault.getVotingVaultManager();
      const vaultManagerRewardSharePercentage = new BigNumber(await vaultManager.rewardSharePercentage());
      const hasVault = await vaultManager.hasVault(this.vault.address);

      await expect(this.vault.setVotingVaultManager(vaultManager.address)).to.be.rejectedWith(Error);
      assert(contractAddress, vaultManager.address, `Voting manager address should be ${vaultManager.address}`);
      assert(
        new BigNumber(rewardSharePercentage).toFixed(0),
        vaultManagerRewardSharePercentage.toFixed(0),
        `Reward share percentage should be ${vaultManagerRewardSharePercentage}`
      );
      assert(hasVault, true, 'Vault was not registered with voting manager');
    });
  });

  describe('initiateWithdrawal(uint256 amount)', () => {
    it('should be able to initiate withdrawal', async () => {
      const currentBalance = new BigNumber(await this.vault.getNonvotingBalance());
      const withdrawAmount = new BigNumber('1e9');

      await this.vault.initiateWithdrawal(withdrawAmount.toString());

      assert.equal(
        new BigNumber(await this.vault.getNonvotingBalance()).toFixed(0),
        currentBalance.minus(withdrawAmount).toFixed(0),
        `Updated non-voting balance doesn't match after withdrawal`
      );
    });

    it('should not be able to initiate withdrawal with amount larger than owned non-voting golds', async () => {
      const withdrawAmount = new BigNumber('1e18');

      await expect(this.mockVault.initiateWithdrawal(withdrawAmount.toString())).to.be.rejectedWith(Error);
    });
  });

  describe('cancelWithdrawal(uint256 index, uint256 amount)', () => {
    it('should be able to initiate withdrawal and then cancel it', async () => {
      const currentBalance = new BigNumber(await this.vault.getNonvotingBalance());
      const withdrawAmount = new BigNumber('1e9');

      await this.vault.initiateWithdrawal(withdrawAmount.toString());
      await this.vault.cancelWithdrawal(0, withdrawAmount.toString());

      assert.equal(
        new BigNumber(await this.vault.getNonvotingBalance()).toFixed(0),
        currentBalance.toFixed(0),
        `Vault's non-voting balance shouldn't change after withdrawal cancellation`
      );
    });

    it('should not be able to cancel non-existent withdrawal', async () => {
      const withdrawAmount = new BigNumber('1e9');

      await expect(this.vault.cancelWithdrawal(withdrawAmount.toString())).to.be.rejectedWith(Error);
    });
  });

  describe('withdraw(uint256 index)', () => {
    it('should be able to withdraw after the unlocking period has passed', async () => {
      await this.mockVault.deposit({
        value: new BigNumber('1e10')
      });

      const currentBalance = new BigNumber(await this.mockVault.getNonvotingBalance());
      const withdrawAmount = new BigNumber('1e9');

      // Set the unlocking period to 0 second so that funds can be withdrawn immediately
      await this.mockLockedGold.setUnlockingPeriod(0);

      await this.mockVault.initiateWithdrawal(withdrawAmount.toString());
      await this.mockVault.withdraw(0);

      assert.equal(
        new BigNumber(await this.mockVault.getNonvotingBalance()).toFixed(0),
        currentBalance.minus(withdrawAmount).toFixed(0),
        `Updated non-voting balance doesn't match after withdrawal`
      );

      assert.equal(
        new BigNumber(await kit.web3.eth.getBalance(this.mockVault.address)).toFixed(0),
        withdrawAmount.toFixed(0),
        `Vault's main balance doesn't match the withdrawn amount`
      );
    });

    it('should not be able to withdraw before the unlocking period has passed', async () => {
      const withdrawAmount = new BigNumber('1e9');

      // Set the unlocking period to 1 day so that no funds are transfered to the Vault
      await this.mockLockedGold.setUnlockingPeriod(86400);

      await this.mockVault.initiateWithdrawal(withdrawAmount.toString());

      await expect(this.mockVault.withdraw(0)).to.be.rejectedWith(Error);
    });
  });
});
