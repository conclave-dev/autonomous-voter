const { contract } = require('@openzeppelin/test-environment');
const { expect } = require('chai');
const { defaultSender } = require('./config');

const Vault = contract.fromArtifact('Vault');

describe('Vault', function () {
  it('should have a valid address', async function () {
    this.vaultContract = await Vault.new({ from: defaultSender });
    expect(this.vaultContract.address).to.be.a('string').with.lengthOf(42);
  });
});
