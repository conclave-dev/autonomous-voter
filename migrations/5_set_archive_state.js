const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const ManagerFactory = artifacts.require('ManagerFactory');

module.exports = (deployer) =>
  deployer.then(async () => {
    const archive = await Archive.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const managerFactory = await ManagerFactory.deployed();
    const hasVaultFactory = (await archive.vaultFactory()) === vaultFactory.address;
    const hasManagerFactory = (await archive.managerFactory()) === managerFactory.address;

    if (!hasVaultFactory) {
      await archive.setVaultFactory(vaultFactory.address);
    }

    if (!hasManagerFactory) {
      await archive.setManagerFactory(managerFactory.address);
    }
  });
