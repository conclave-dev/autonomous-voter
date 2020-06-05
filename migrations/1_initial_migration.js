const {
  scripts: { init },
  ConfigManager
} = require('@openzeppelin/cli');
const Migrations = artifacts.require('Migrations');
const { name, version } = require('../package.json');
const { getProjectFile } = require('./util');

// Initializes an OZ project if it does not yet exist
const initProject = async (network) => {
  const projectFile = getProjectFile(network);

  if (projectFile.exists()) {
    return;
  }

  await init({
    name,
    version
  });
};

module.exports = async (deployer, networkName, accounts) => {
  const { network } = await ConfigManager.initNetworkConfiguration({
    network: networkName,
    from: accounts[0]
  });

  await initProject(network);

  deployer.deploy(Migrations);
};
