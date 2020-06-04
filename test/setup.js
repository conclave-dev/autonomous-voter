const chai = require('chai');
const BigNumber = require('bignumber.js');
const { contract } = require('@openzeppelin/test-environment');
const { encodeCall } = require('@openzeppelin/upgrades');
const {
  networks: { development }
} = require('../networks');
const { app } = require(`../.openzeppelin/dev-${development.networkId}.json`);

chai.use(require('chai-as-promised'));

const Archive = contract.fromArtifact('Archive');
const Vault = contract.fromArtifact('Vault');
const VaultAdmin = contract.fromArtifact('VaultAdmin');
const VaultFactory = contract.fromArtifact('VaultFactory');

before(async function () {
  this.kit = await require('@celo/contractkit').newKit(
    `${development.protocol}://${development.host}:${development.port}`
  );

  this.address = {
    primary: development.from,
    secondary: '0x6Ecbe1DB9EF729CBe972C83Fb886247691Fb6beb',
    zero: '0x0000000000000000000000000000000000000000',
    appContract: app.address,
    registryContract: '0x000000000000000000000000000000000000ce10'
  };
  this.defaultTx = { from: this.address.primary };
  this.defaultTxValue = new BigNumber(1).multipliedBy('1e18');

  this.createArchive = async () => {
    const archive = await Archive.new(this.defaultTx);
    await archive.initialize(this.address.primary, this.defaultTx);
    return archive;
  };

  this.createVaultFactory = async (appAddress, archiveAddress) => {
    const vaultFactory = await VaultFactory.new(this.defaultTx);
    await vaultFactory.initialize(appAddress, archiveAddress, this.defaultTx);
    return vaultFactory;
  };

  this.createVault = async (msgSender, archive, vaultFactory) => {
    // Set vaultFactory in Archive so that our vault factory can update its `vaults` variable
    await archive.setVaultFactory(vaultFactory.address, this.defaultTx);

    const initializeVault = encodeCall(
      'initializeVault',
      ['address', 'address'],
      [this.address.registryContract, msgSender]
    );
    const { logs } = await vaultFactory.createInstance(initializeVault, {
      from: msgSender,
      value: this.defaultTxValue
    });

    // Parse the admin address from the event logs, and get the instance
    const vault = await Vault.at(logs[0].args[0]);
    const adminAddress = logs[1].args[0];

    await vault.updateVaultAdmin(adminAddress, {
      from: msgSender
    });

    return vault;
  };

  this.archive = await this.createArchive();
  this.vaultFactory = await this.createVaultFactory(app.address, this.archive.address);
  this.vault = await this.createVault(this.address.primary, this.archive, this.vaultFactory);
  this.vaultAdmin = await VaultAdmin.at(await this.vault.vaultAdmin());
});

module.exports = {
  expect: chai.expect
};
