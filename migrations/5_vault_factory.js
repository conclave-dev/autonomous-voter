const VaultFactory = artifacts.require('VaultFactory');
const App = artifacts.require('App');
const Archive = artifacts.require('Archive');

module.exports = async (deployer) => {
  await deployer.deploy(VaultFactory);

  const vaultFactory = await VaultFactory.deployed();

  if (await vaultFactory.archive()) {
    return;
  }

  const { address: appAddress } = App.deployed();
  const { address: archiveAddress } = Archive.deployed();

  await vaultFactory.initialize(appAddress, archiveAddress);
};
