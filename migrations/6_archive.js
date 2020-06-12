const Archive = artifacts.require('Archive');
const { registryContractAddress } = require('../config');

module.exports = async (deployer) => {
  await deployer.deploy(Archive);

  const archive = await Archive.deployed();

  await archive.initialize(registryContractAddress);
};
