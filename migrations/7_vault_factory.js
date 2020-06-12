const VaultFactory = artifacts.require('VaultFactory');
const App = artifacts.require('App');
const Archive = artifacts.require('Archive');

module.exports = async (deployer) => {
  await deployer.deploy(VaultFactory);

  const vaultFactory = await VaultFactory.deployed();
  const { address: appAddress } = await App.deployed();
  const { address: archiveAddress } = await Archive.deployed();

  await vaultFactory.initialize(appAddress, archiveAddress);
};
