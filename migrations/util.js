const {
  scripts: { add, push, publish },
  files: { ProjectFile },
  ConfigManager
} = require('@openzeppelin/cli');
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

const getProjectFile = network => new ProjectFile(`${__dirname}/../.openzeppelin/${network}.json`);

module.exports = {
  deployContract,
  getProjectFile
};
