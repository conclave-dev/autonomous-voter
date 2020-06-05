const Migrations = artifacts.require('Migrations');
const { initProject } = require('../util/openzeppelin');

module.exports = async (deployer, network, accounts) => {
  // Initialize OZ project
  await initProject(network, accounts[0]);

  return deployer.deploy(Migrations);
};
