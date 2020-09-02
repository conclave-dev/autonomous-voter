const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');

module.exports = (deployer) =>
  deployer.then(async () => {
    const archive = await Archive.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const hasVaultFactory = (await archive.vaultFactory()) === vaultFactory.address;

    if (!hasVaultFactory) {
      await archive.setVaultFactory(vaultFactory.address);
    }
  });
