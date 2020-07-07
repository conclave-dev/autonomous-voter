const { assert } = require('./setup');

describe('Archive', () => {
  before(async function () {
    // Setup done for testing the Archive's tracking for managed vaults
    const manager = await this.persistentVaultInstance.manager();

    // Set the vote manager, which will also serve as the test for Archive's `associateVaultWithManager` method
    if (manager === this.zeroAddress) {
      await this.persistentVaultInstance.setVoteManager(this.persistentVoteManagerInstance.address);
    }
  });

  after(async function () {
    // Unset the vote manager, which will also serve as the test for Archive's `dissociateVaultFromManager` method
    await this.persistentVaultInstance.removeVoteManager();
  });

  describe('State', function () {
    it('should have a vault factory', async function () {
      return assert.equal(await this.archive.vaultFactory(), this.vaultFactory.address);
    });

    it('should have a manager factory', async function () {
      return assert.equal(await this.archive.managerFactory(), this.managerFactory.address);
    });

    it(`should have a mapping to track user's vault instances`, async function () {
      const primarySenderVaults = await this.archive.getVaultsByOwner(this.primarySender);
      return assert.isTrue(primarySenderVaults.length > 0);
    });

    it(`should have a mapping to track user's manager instances`, async function () {
      const primarySenderManagers = await this.archive.getManagersByOwner(this.primarySender);
      return assert.isTrue(primarySenderManagers.length > 0);
    });

    it(`should have a mapping to track managed vaults with their managers`, async function () {
      const managedVaults = await this.archive.getManagedVaultsByManager(this.persistentVoteManagerInstance.address);
      return assert.isTrue(managedVaults.length > 0);
    });
  });

  describe('Methods ✅', function () {
    it('should initialize with an owner', async function () {
      return assert.equal(await this.archive.owner(), this.primarySender);
    });

    it('should initialize with the Celo Registry contract', async function () {
      return assert.equal(await this.archive.registry(), this.registryContractAddress);
    });

    it('should allow the owner to set the vault factory', function () {
      return assert.isFulfilled(this.archive.setVaultFactory(this.vaultFactory.address));
    });

    it('should allow the owner to set the manager factory', function () {
      return assert.isFulfilled(this.archive.setManagerFactory(this.managerFactory.address));
    });

    it('should check valid ownership of a vault', async function () {
      return assert.isTrue(await this.archive.hasVault(this.primarySender, this.vaultInstance.address));
    });

    it('should check valid ownership of a manager', async function () {
      return assert.isTrue(await this.archive.hasManager(this.primarySender, this.managerInstance.address));
    });

    it('should check valid managed vault', async function () {
      return assert.isTrue(
        await this.archive.isManagedVault(
          this.persistentVaultInstance.address,
          this.persistentVoteManagerInstance.address
        )
      );
    });
  });

  describe('Methods 🛑', function () {
    it('should disallow non-owners from setting the vault factory', function () {
      return assert.isRejected(this.archive.setVaultFactory(this.vaultFactory.address, { from: this.secondarySender }));
    });

    it('should disallow non-owners from setting the manager factory', function () {
      return assert.isRejected(
        this.archive.setManagerFactory(this.managerFactory.address, { from: this.secondarySender })
      );
    });

    it('should check invalid ownership of a vault', async function () {
      return assert.isFalse(await this.archive.hasVault(this.secondarySender, this.vaultInstance.address));
    });

    it('should check invalid ownership of a manager', async function () {
      return assert.isFalse(await this.archive.hasManager(this.secondarySender, this.managerInstance.address));
    });

    it('should check invalid managed vault', async function () {
      return assert.isFalse(
        await this.archive.isManagedVault(this.primarySender, this.persistentVoteManagerInstance.address)
      );
    });
  });
});
