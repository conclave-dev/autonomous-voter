const {
  defaultTx,
  expect,
  createVault,
  DEFAULT_SENDER_ADDRESS,
  ZERO_ADDRESS,
  SECONDARY_ADDRESS,
  REGISTRY_CONTRACT_ADDRESS
} = require('./setup');

describe('Archive', function () {
  describe('Initialize', function () {
    it('should initialize', function () {
      expect(typeof this.archive.address).to.equal('string');
      expect(this.archive.address.length).to.equal(42);
      expect(this.archive.address).to.not.equal(ZERO_ADDRESS);
    });

    it('should have an owner', async function () {
      const owner = (await this.archive.owner()).toLowerCase();

      expect(owner).to.not.equal(SECONDARY_ADDRESS);
      expect(owner).to.equal(DEFAULT_SENDER_ADDRESS);
    });
  });

  describe('Ownership', function () {
    it('should not set vaultFactory if not owner', async function () {
      await expect(
        this.archive.setVaultFactory(this.vaultFactory.address, { from: SECONDARY_ADDRESS })
      ).to.be.rejectedWith(Error);
    });

    it('should set vaultFactory if owner', async function () {
      const { logs } = await this.archive.setVaultFactory(this.vaultFactory.address, defaultTx);
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
          this.archive.updateVault(this.vault.address, SECONDARY_ADDRESS, { from: SECONDARY_ADDRESS })
        ).to.be.rejectedWith(
          'Returned error: VM Exception while processing transaction: revert Sender is not vault factory -- Reason given: Sender is not vault factory.'
        );
      });

      it('should set a vault if vault factory', async function () {
        expect(await this.archive.vaults(SECONDARY_ADDRESS)).to.equal(ZERO_ADDRESS);

        const _vault = await createVault(REGISTRY_CONTRACT_ADDRESS, SECONDARY_ADDRESS, this.archive, this.vaultFactory);

        expect(await this.archive.vaults(SECONDARY_ADDRESS)).to.equal(_vault.address);
      });
    });
  });
});
