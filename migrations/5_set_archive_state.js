const Archive = artifacts.require('Archive');
const VaultFactory = artifacts.require('VaultFactory');
const VotingVaultManagerFactory = artifacts.require('VotingVaultManagerFactory');
const MockArchive = artifacts.require('MockArchive');
const MockVaultFactory = artifacts.require('MockVaultFactory');

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
      console.log('setting vault manager factory', votingVaultManagerFactory.address);
      await archive.setVaultManagerFactory(votingVaultManagerFactory.address);
    }

    const mockArchive = await MockArchive.deployed();
    const mockVaultFactory = await MockVaultFactory.deployed();
    const hasMockVaultFactory = (await mockArchive.vaultFactory()) === mockVaultFactory.address;
    // For now, it shares the same instance for VaultManagerFactory as we don't yet need a mock version of it
    const hasMockVaultManagerFactory = (await mockArchive.vaultManagerFactory()) === votingVaultManagerFactory.address;

    if (!hasMockVaultFactory) {
      await mockArchive.setVaultFactory(mockVaultFactory.address);
    }

    if (!hasMockVaultManagerFactory) {
      await mockArchive.setVaultManagerFactory(votingVaultManagerFactory.address);
    }
  });
