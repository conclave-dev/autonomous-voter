// test/Vault.test.js

const { contract } = require('@openzeppelin/test-environment');
const { defaultSender } = require('./config');

const { expect } = require('chai');

const Vault = contract.fromArtifact('Vault');

describe('Vault', function () {
  it('the contract address should be valid', async function () {
    this.vaultContract = await Vault.new({ from: defaultSender });
    expect(this.vaultContract.address).to.be.a('string').with.lengthOf(42);
  });
});
