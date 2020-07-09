const BigNumber = require('bignumber.js');
const { assert } = require('./setup');

describe('VoteManager', function () {
  before(async function () {
    const voteManager = (await this.persistentVaultInstance.getVoteManager())[0];

    if (voteManager === this.zeroAddress) {
      await this.persistentVaultInstance.setVoteManager(this.persistentVoteManagerInstance.address);
    }

    const electionMethods = (await this.kit._web3Contracts.getElection()).methods;
    const groups = (await (await electionMethods.getTotalVotesForEligibleValidatorGroups()).call())[0];
    const group = groups[0];
    const lesser = groups[1];
    const greater = this.zeroAddress;
    const defaultVotes = new BigNumber(1);
    const getPendingVotes = async () =>
      new BigNumber(
        await (
          await electionMethods.getPendingVotesForGroupByAccount(group, this.persistentVaultInstance.address)
        ).call()
      );

    this.voteForVault = async (vault) => {
      const prevotePendingAmount = await getPendingVotes();

      await this.persistentVoteManagerInstance.vote(vault, group, defaultVotes, lesser, greater);

      const postvotePendingAmount = await getPendingVotes();

      return {
        votes: defaultVotes,
        prevotePendingAmount,
        postvotePendingAmount
      };
    };

    this.revokePendingVotesForVault = async (vault) => {
      const prevotePendingAmount = await getPendingVotes();
      const groupsVotedFor = await (
        await electionMethods.getGroupsVotedForByAccount(this.persistentVaultInstance.address)
      ).call();
      const accountGroupIndex = groupsVotedFor.indexOf(group);

      await this.persistentVoteManagerInstance.revokePending(
        vault,
        group,
        defaultVotes,
        lesser,
        greater,
        accountGroupIndex
      );

      const postvotePendingAmount = await getPendingVotes();

      return {
        votes: defaultVotes,
        prevotePendingAmount,
        postvotePendingAmount
      };
    };
  });

  describe('Methods ✅', function () {
    it('should vote for a managed vault', async function () {
      const { votes, prevotePendingAmount, postvotePendingAmount } = await this.voteForVault(
        this.persistentVaultInstance.address
      );

      return assert.isTrue(prevotePendingAmount.plus(votes).isEqualTo(postvotePendingAmount));
    });

    it('should revoke pending votes for a managed vault', async function () {
      const { votes, prevotePendingAmount, postvotePendingAmount } = await this.revokePendingVotesForVault(
        this.persistentVaultInstance.address
      );

      return assert.isTrue(prevotePendingAmount.minus(votes).isEqualTo(postvotePendingAmount));
    });
  });

  describe('Methods 🛑', function () {
    it('should not vote for an unmanaged vault', function () {
      return assert.isRejected(this.voteForVault(this.vaultInstance.address));
    });

    it('should not revoke pending votes for an unmanaged vault', function () {
      return assert.isRejected(this.revokePendingVotesForVault(this.vaultInstance.address));
    });
  });
});
