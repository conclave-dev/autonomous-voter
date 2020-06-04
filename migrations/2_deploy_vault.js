const {
  scripts: { add, push, publish },
  ConfigManager
} = require('@openzeppelin/cli');
const Vault = artifacts.require('Vault');

const create = async (options) => {
  // oz add --all
  await add({
    contractsData: [{ name: 'Vault', alias: 'Vault' }]
  });

  // oz push --network networkName --from ourAddress
  await push(options);

  // oz publish --network networkName --from ourAddress
  await publish(options);
};

module.exports = async (deployer, networkName, accounts) => {
  await deployer.deploy(Vault);

  await deployer.then(async () => {
    const { network, txParams } = await ConfigManager.initNetworkConfiguration({
      network: networkName,
      from: accounts[0]
    });

    await create({
      network,
      txParams
    });
  });
};
