const Archive = artifacts.require('Archive');

module.exports = async (deployer, _, accounts) => {
  await deployer.deploy(Archive);

  const archive = await Archive.deployed();

  await archive.initialize(accounts[0]);
};
