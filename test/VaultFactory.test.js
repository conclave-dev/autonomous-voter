const { contract } = require('@openzeppelin/test-environment');
const { defaultSender } = require('./config');
const { expect } = require('chai');

const App = contract.fromArtifact('App');
const VaultFactory = contract.fromArtifact('VaultFactory');

describe('VaultFactory', function () {
  it('should initialize with an App contract address', async function () {
    this.appContract = await App.new({ from: defaultSender });
    this.vaultFactoryContract = await VaultFactory.new({ from: defaultSender });
    const { receipt } = await this.vaultFactoryContract.initialize.sendTransaction(this.appContract.address, {
      from: defaultSender
    });

    expect(receipt.status).to.be.true;
  });
});
