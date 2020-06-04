const {
  scripts: { init },
  files: { ProjectFile },
  ConfigManager
} = require('@openzeppelin/cli');
const Migrations = artifacts.require('Migrations');
const { name, version } = require('../package.json');

// Initializes an OZ project if it does not yet exist
const initProject = async ({ network, txParams }) => {
  const projectFile = new ProjectFile(`${__dirname}/../.openzeppelin/${network}.json`);

  if (projectFile.exists()) {
    return;
  }

  await init({
    name,
    version
  });
};

module.exports = async (deployer, networkName, accounts) => {
  const { network, txParams } = await ConfigManager.initNetworkConfiguration({
    network: networkName,
    from: accounts[0]
  });

  await initProject({ network, txParams });

  deployer.deploy(Migrations);
};
