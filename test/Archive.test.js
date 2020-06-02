const { expect } = require('./setup');

describe('Archive', function () {
  describe('Initialize', function () {
    it('should initialize', function () {
      expect(typeof this.archive.address).to.equal('string');
      expect(this.archive.address.length).to.equal(42);
      expect(this.archive.address).to.not.equal(this.address.zero);
    });

    it('should have an owner', async function () {
      const owner = await this.archive.owner();

      expect(owner).to.not.equal(this.address.secondary);
      expect(owner.toLowerCase()).to.equal(this.address.primary.toLowerCase());
    });
  });

  describe('Ownership', function () {
    it('should not set vaultFactory if not owner', async function () {
      await expect(
        this.archive.setVaultFactory(this.vaultFactory.address, { from: this.address.secondary })
      ).to.be.rejectedWith(Error);
    });

    it('should set vaultFactory if owner', async function () {
      const { logs } = await this.archive.setVaultFactory(this.vaultFactory.address, this.defaultTx);
      const { event, args } = logs[0];

      expect(await this.archive.vaultFactory()).to.equal(this.vaultFactory.address);
      expect(args[0]).to.equal(this.vaultFactory.address); // Check event emitted with correct value
      expect(event).to.equal('VaultFactorySet');
    });
  });

  describe('Methods', function () {
    describe('updateVault(address vault)', function () {
      it('should not set a vault if not vault factory', async function () {
        await expect(
          this.archive.updateVault(this.vault.address, this.address.secondary, { from: this.address.secondary })
        ).to.be.rejectedWith(
          'Returned error: VM Exception while processing transaction: revert Sender is not vault factory -- Reason given: Sender is not vault factory.'
        );
      });

      it('should set a vault if vault factory', async function () {
        expect(await this.archive.vaults(this.address.secondary)).to.equal(this.address.zero);

        const _vault = await this.createVault(this.address.secondary, this.archive, this.vaultFactory);

        expect(await this.archive.vaults(this.address.secondary)).to.equal(_vault.address);
      });
    });
  });
});
