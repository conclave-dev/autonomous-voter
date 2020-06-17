const BigNumber = require('bignumber.js');
const VaultFactory = artifacts.require('VaultFactory');
const VotingVaultManagerFactory = artifacts.require('VotingVaultManagerFactory');
const Archive = artifacts.require('Archive');
const { registryContractAddress, primarySenderAddress } = require('../config');

module.exports = (deployer) =>
  deployer.then(async () => {
    const vaultFactory = await VaultFactory.deployed();
    const vaultManagerFactory = await VotingVaultManagerFactory.deployed();
    const archive = await Archive.deployed();

    await vaultFactory.createInstance(registryContractAddress, {
      value: new BigNumber('1e17')
    });
    await vaultManagerFactory.createInstance(new BigNumber(10), new BigNumber(1e16));

    console.log('vaults', await archive.getVaultsByOwner(primarySenderAddress));
    console.log('vault managers', await archive.getVaultManagersByOwner(primarySenderAddress));
  });
