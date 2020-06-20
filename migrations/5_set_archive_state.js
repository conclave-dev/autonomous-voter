const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const VotingVaultManagerFactory = artifacts.require('VotingVaultManagerFactory');

module.exports = (deployer) =>
  deployer.then(async () => {
    const archive = await Archive.deployed();
    const vaultFactory = await VaultFactory.deployed();
    const votingVaultManagerFactory = await VotingVaultManagerFactory.deployed();
    const hasVaultFactory = (await archive.vaultFactory()) === vaultFactory.address;
    const hasVotingVaultManagerFactory = (await archive.vaultManagerFactory()) === votingVaultManagerFactory.address;

    if (!hasVaultFactory) {
      await archive.setVaultFactory(vaultFactory.address);
    }

    if (!hasVotingVaultManagerFactory) {
      await archive.setVaultManagerFactory(votingVaultManagerFactory.address);
    }
  });
