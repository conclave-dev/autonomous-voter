const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const VaultManagerFactory = artifacts.require('VaultManagerFactory');

module.exports = (deployer) =>
  deployer.then(async () => {
    const archive = await Archive.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const vaultManagerFactory = await VaultManagerFactory.deployed();
    const hasVaultFactory = (await archive.vaultFactory()) === vaultFactory.address;
    const hasVaultManagerFactory = (await archive.vaultManagerFactory()) === vaultManagerFactory.address;

    if (!hasVaultFactory) {
      await archive.setVaultFactory(vaultFactory.address);
    }

    if (!hasVaultManagerFactory) {
      await archive.setVaultManagerFactory(vaultManagerFactory.address);
    }
  });
