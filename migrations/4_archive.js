const Archive = artifacts.require('Archive');

module.exports = async (deployer, _, accounts) => {
  await deployer.deploy(Archive);

  const archive = await Archive.deployed();

  console.log('await archive.owner()', await archive.owner());

  if (await archive.owner()) {
    return;
  }

  await archive.initialize(accounts[0]);
};
