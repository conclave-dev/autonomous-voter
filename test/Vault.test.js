const { contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const { DEFAULT_SENDER_ADDRESS } = require('./config');

const Vault = contract.fromArtifact('Vault');

describe('Vault', function () {
  it('should have a valid address', async function () {
    this.vaultContract = await Vault.new({ from: DEFAULT_SENDER_ADDRESS });

    expect(this.vaultContract.address).to.be.a('string').with.lengthOf(42);
  });
});
