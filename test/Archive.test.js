const { assert } = require('./setup');

describe('Archive', () => {
  describe('State', function () {
    it('should have a vault factory', async function () {
      return assert.equal(await this.archive.vaultFactory(), this.vaultFactory.address);
    });

    it('should have a manager factory', async function () {
      return assert.equal(await this.archive.managerFactory(), this.managerFactory.address);
    });

    it(`should have a user's vault instances`, async function () {
      const primarySenderVaults = await this.archive.getVaultsByOwner(this.primarySender);
      return assert.isTrue(primarySenderVaults.length > 0);
    });

    it(`should have a user's manager instances`, async function () {
      const primarySenderManagers = await this.archive.getManagersByOwner(this.primarySender);
      return assert.isTrue(primarySenderManagers.length > 0);
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
  });
});
