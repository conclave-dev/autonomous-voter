const BigNumber = require('bignumber.js');
const { assert, kit } = require('./setup');

describe('VotingVaultManager', function () {
  describe('vote(address vault,address group,uint256 amount,address adjacentGroupWithLessVotes,address adjacentGroupWithMoreVotes)', function () {
    before(async function () {
      const votingVaultManager = (await this.persistentVaultInstance.getVotingVaultManager())[0];

      if (votingVaultManager === this.zeroAddress) {
        await this.persistentVaultInstance.setVotingVaultManager(this.persistentVaultManagerInstance.address);
      }
    });

    it('should be able to place votes for a managed Vault', async function () {
      const election = await kit._web3Contracts.getElection();
      const groupsVotedFor = await (
        await election.methods.getGroupsVotedForByAccount(this.persistentVaultInstance.address)
      ).call();
      const groups = (await (await election.methods.getTotalVotesForEligibleValidatorGroups()).call())[0];

      // Use the first voted group or select a random eligible group if it doesn't exist
      const group = groupsVotedFor.length ? groupsVotedFor[0] : groups[Math.floor(Math.random() * groups.length)];
      const groupIndex = groups.indexOf(group);

      // Check if the voting group we are voting for is the last element
      // If it is, then lesser is 0, otherwise, get the index of the adjacent group with less votes
      const lesser = groupIndex === groups.length - 1 ? this.zeroAddress : groups[groupIndex + 1];

      // Check if the voting group index is non-zero (i.e. the first element)
      // If it is non-zero, get the index of the adjacent group with more votes, otherwise set to 0
      const greater = groupIndex ? groups[groupIndex - 1] : this.zeroAddress;

      const prevotePendingAmount = new BigNumber(
        await (
          await election.methods.getPendingVotesForGroupByAccount(group, this.persistentVaultInstance.address)
        ).call()
      );
      const votes = new BigNumber(1);

      await this.persistentVaultManagerInstance.vote(
        this.persistentVaultInstance.address,
        group,
        votes,
        lesser,
        greater
      );

      const postvotePendingAmount = new BigNumber(
        await (
          await election.methods.getPendingVotesForGroupByAccount(group, this.persistentVaultInstance.address)
        ).call()
      );

      return assert.equal(
        prevotePendingAmount.plus(votes).isEqualTo(postvotePendingAmount),
        true,
        `Expected ${prevotePendingAmount.plus(votes).toFixed(0)} pending votes`
      );
    });
  });
});
