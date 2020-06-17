const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const VaultManagerFactory = artifacts.require('VaultManagerFactory');
const MockArchive = artifacts.require('MockArchive');
const MockVaultFactory = artifacts.require('MockVaultFactory');

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

    const mockArchive = await MockArchive.deployed();
    const mockVaultFactory = await MockVaultFactory.deployed();
    const hasMockVaultFactory = (await mockArchive.vaultFactory()) === mockVaultFactory.address;
    // For now, it shares the same instance for VaultManagerFactory as we don't yet need a mock version of it
    const hasMockVaultManagerFactory = (await mockArchive.vaultManagerFactory()) === vaultManagerFactory.address;

    if (!hasMockVaultFactory) {
      await mockArchive.setVaultFactory(mockVaultFactory.address);
    }

    if (!hasMockVaultManagerFactory) {
      await mockArchive.setVaultManagerFactory(vaultManagerFactory.address);
    }
  });
