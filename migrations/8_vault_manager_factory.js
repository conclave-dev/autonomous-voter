const VaultManagerFactory = artifacts.require('VaultManagerFactory');
const App = artifacts.require('App');
const Archive = artifacts.require('Archive');

module.exports = async (deployer) => {
  await deployer.deploy(VaultManagerFactory);

  const vaultManagerFactory = await VaultManagerFactory.deployed();
  const { address: appAddress } = await App.deployed();
  const { address: archiveAddress } = await Archive.deployed();

  await vaultManagerFactory.initialize(appAddress, archiveAddress);
};
