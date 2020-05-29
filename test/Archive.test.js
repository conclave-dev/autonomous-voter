const { contract } = require('@openzeppelin/test-environment');
const { expect, DEFAULT_SENDER_ADDRESS } = require('./config');

const Archive = contract.fromArtifact('Archive');
const VaultFactory = contract.fromArtifact('VaultFactory');
const Vault = contract.fromArtifact('Vault');

describe('Archive', function () {
  before(async function () {
    this.archive = await Archive.new({ from: DEFAULT_SENDER_ADDRESS });
    this.vaultFactoryAddress = (await VaultFactory.new({ from: DEFAULT_SENDER_ADDRESS })).address;
    this.vaultAddress = (await Vault.new({ from: DEFAULT_SENDER_ADDRESS })).address;
    this.defaultTx = { from: DEFAULT_SENDER_ADDRESS };
    this.getArchiveOwner = async () => (await this.archive.owner()).toLowerCase();
  });

  it('should create contract without an owner', async function () {
    expect(await this.getArchiveOwner()).to.equal('0x0000000000000000000000000000000000000000');
  });

  it('should set an owner by calling initialize', async function () {
    await this.archive.initialize(DEFAULT_SENDER_ADDRESS, this.defaultTx);

    expect(await this.getArchiveOwner()).to.equal(DEFAULT_SENDER_ADDRESS);
  });

  describe('Access Control', function () {
    it('should not change vaultFactory if not owner', async function () {
      const nonOwnerTx = { from: '0x57c445eaea6b8782b75a50e2069fc209386541f1' };

      await expect(this.archive.setVaultFactory(this.vaultFactoryAddress, nonOwnerTx)).to.be.rejectedWith(
        'Returned error: sender account not recognized -- Reason given: Ownable: caller is not the owner.'
      );
      expect(await this.archive.vaultFactory()).to.equal('0x0000000000000000000000000000000000000000');
    });

    it('should change vaultFactory if owner', async function () {
      const { logs } = await this.archive.setVaultFactory(this.vaultFactoryAddress, this.defaultTx);
      const { event, args } = logs[0];
      const eventArg = args[0];

      expect(await this.archive.vaultFactory()).to.equal(this.vaultFactoryAddress);
      expect(eventArg).to.equal(this.vaultFactoryAddress); // Check event emitted with correct value
      expect(event).to.equal('VaultFactorySet');
    });
  });

  describe('Vaults', function () {
    it('should map the message sender to the address arg', async function () {
      const { logs } = await this.archive.updateVault(this.vaultAddress, this.defaultTx);
      const { event, args } = logs[0];
      const eventArg = args[0];

      expect(await this.archive.vaults(DEFAULT_SENDER_ADDRESS)).to.equal(this.vaultAddress);
      expect(eventArg.toLowerCase()).to.equal(DEFAULT_SENDER_ADDRESS); // Check event emitted with correct value
      expect(event).to.equal('VaultUpdated');
    });
  });
});
