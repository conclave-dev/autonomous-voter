const { newKit } = require('@celo/contractkit');
const { MD5 } = require('crypto-js');

// Retrieves the deployed bytecode of a deployed contract against the artifact's deployed bytecode
const compareDeployedBytecodes = async (deployer, deployedContractAddress, artifactDeployedBytecode) => {
  const kit = newKit(deployer.provider.host);
  const deployedChecksum = MD5(await kit.web3.eth.getCode(deployedContractAddress)).toString();
  const artifactChecksum = MD5(artifactDeployedBytecode).toString();

  return deployedChecksum === artifactChecksum;
};

module.exports = {
  compareDeployedBytecodes
};
