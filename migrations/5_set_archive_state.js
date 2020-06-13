const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const VaultManagerFactory = artifacts.require('VaultManagerFactory');

module.exports = (deployer) => {
  deployer.then(async () => {
    const archive = await Archive.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const vaultManagerFactory = await VaultManagerFactory.deployed();

    await archive.setVaultFactory(vaultFactory.address);
    await archive.setVaultManagerFactory(vaultManagerFactory.address);
  });
};
