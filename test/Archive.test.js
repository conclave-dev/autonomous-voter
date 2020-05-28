const { contract } = require('@openzeppelin/test-environment');
const chai = require('chai');
const { DEFAULT_SENDER_ADDRESS } = require('./config');

chai.use(require('chai-as-promised'));

const expect = chai.expect;
const Archive = contract.fromArtifact('Archive');

describe('Archive', function () {
  it('should create contract without an owner', async function () {
    this.archive = await Archive.new({ from: DEFAULT_SENDER_ADDRESS });
    const archiveOwner = (await this.archive.owner()).toLowerCase();

    expect(archiveOwner).to.equal('0x0000000000000000000000000000000000000000');
  });

  it('should set an owner by calling initialize', async function () {
    await this.archive.initialize.sendTransaction(DEFAULT_SENDER_ADDRESS, {
      from: DEFAULT_SENDER_ADDRESS
    });
    const archiveOwner = (await this.archive.owner()).toLowerCase();

    expect(archiveOwner).to.equal(DEFAULT_SENDER_ADDRESS);
  });

  describe('Access Control', function () {
    it('should not change vaultFactory if not owner', async function () {
      this.vaultFactory = await contract.fromArtifact('VaultFactory').new({ from: DEFAULT_SENDER_ADDRESS });
      const nonOwnerAddress = '0x57c445eaea6b8782b75a50e2069fc209386541f1';

      await expect(
        this.archive.setVaultFactory.sendTransaction(this.vaultFactory.address, {
          from: nonOwnerAddress
        })
      ).to.be.rejectedWith(Error);
    });

    it('should change vaultFactory if owner', async function () {
      expect(await this.archive.vaultFactory()).to.equal('0x0000000000000000000000000000000000000000');

      this.archive.setVaultFactory.sendTransaction(this.vaultFactory.address, {
        from: DEFAULT_SENDER_ADDRESS
      });

      expect(await this.archive.vaultFactory()).to.equal(this.vaultFactory.address);
    });
  });
});
