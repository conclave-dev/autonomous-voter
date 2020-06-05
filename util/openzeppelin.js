const {
  scripts: { init, add, push, publish },
  files: { ProjectFile },
  ConfigManager
} = require('@openzeppelin/cli');
const { name, version } = require('../package.json');

// Initializes an OZ project if it does not yet exist
const initProject = async (networkName, from) => {
  const projectFile = await getProjectFile(networkName, from);

  if (projectFile.exists()) {
    return;
  }

  await init({
    name,
    version
  });
};

const deployContract = async (contractName, networkName, deployerAddress) => {
  const { network, txParams } = await ConfigManager.initNetworkConfiguration({
    network: networkName,
    from: deployerAddress
  });

  // oz add --all
  await add({
    contractsData: [{ name: contractName, alias: contractName }]
  });

  // oz push --network networkName --from ourAddress
  await push({ network, txParams });

  // oz publish --network networkName --from ourAddress
  await publish({ network, txParams });
};

const getNetworkConfig = (network, from) =>
  ConfigManager.initNetworkConfiguration({
    from,
    network
  });

const getProjectFile = async (networkName, from) => {
  const { network } = await getNetworkConfig(networkName, from);
  return new ProjectFile(`${__dirname}/../.openzeppelin/${network}.json`);
};

module.exports = {
  initProject,
  deployContract,
  getNetworkConfig,
  getProjectFile
};
