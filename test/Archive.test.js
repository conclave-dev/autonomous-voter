const { contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const { DEFAULT_SENDER_ADDRESS } = require('./config');

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
});
