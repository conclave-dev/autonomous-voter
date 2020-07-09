const Promise = require('bluebird');
const { newKit } = require('@celo/contractkit');
const { MD5 } = require('crypto-js');

// Retrieves the deployed bytecode of a deployed contract against the artifact's deployed bytecode
const compareDeployedBytecodes = async (deployer, deployedContractAddress, artifactDeployedBytecode) => {
  const kit = newKit(deployer.provider.host);
  const deployedChecksum = MD5(await kit.web3.eth.getCode(deployedContractAddress)).toString();
  const artifactChecksum = MD5(artifactDeployedBytecode).toString();

  return deployedChecksum === artifactChecksum;
};

const contractHasUpdates = async (deployer, network, contract) => {
  if (network === 'local') {
    return true;
  }

  try {
    // Update contracts if the deployed contract runtime bytecodes differ from Truffle's
    // NOTE: A few contracts (such as Archive) will always update. Need to come up with better solution
    const { address } = await contract.deployed();
    return !(await compareDeployedBytecodes(deployer, address, contract.deployedBytecode));
  } catch (err) {
    console.error(err);
  }
};

const deployContracts = async (deployer, network, contracts) => {
  await Promise.each(contracts, async (contract) => {
    await deployer.deploy(contract, { overwrite: await contractHasUpdates(deployer, network, contract) });
  });
};

module.exports = {
  compareDeployedBytecodes,
  deployContracts,
  contractHasUpdates
};
