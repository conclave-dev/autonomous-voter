const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');

module.exports = async (deployer) => {
  deployer.then(async () => {
    const archive = await Archive.deployed();
    const vaultFactory = await VaultFactory.deployed();

    await archive.setVaultFactory(vaultFactory.address);
  });
};
