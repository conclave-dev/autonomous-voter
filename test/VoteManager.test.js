const BigNumber = require('bignumber.js');
const { assert } = require('./setup');

describe('VoteManager', function () {
  before(async function () {
    const manager = await this.persistentVaultInstance.manager();

    if (manager === this.zeroAddress) {
      await this.persistentVaultInstance.setVoteManager(this.persistentVoteManagerInstance.address);
    }

    this.election = (await this.kit._web3Contracts.getElection()).methods;
  });

  // Runs before each test in case group ordering changes
  beforeEach(async function () {
    const groupsVotedFor = await (
      await this.election.getGroupsVotedForByAccount(this.persistentVaultInstance.address)
    ).call();
    const groups = (await (await this.election.getTotalVotesForEligibleValidatorGroups()).call())[0];

    // Use the first voted group or select a random eligible group if it doesn't exist
    this.group = groupsVotedFor.length ? groupsVotedFor[0] : groups[Math.floor(Math.random() * groups.length)];
    this.groupIndex = groups.indexOf(this.group);

    // Check if the group we are voting for is the last element
    // If it is, then lesser is 0, otherwise, get the index of the adjacent group with less votes
    this.lesser = this.groupIndex === groups.length - 1 ? this.zeroAddress : groups[this.groupIndex + 1];

    // Check if the group index is non-zero (i.e. the first element)
    // If it is non-zero, get the index of the adjacent group with more votes, otherwise set to 0
    this.greater = this.groupIndex ? groups[this.groupIndex - 1] : this.zeroAddress;

    this.defaultVotes = new BigNumber(1);
  });

  describe('Methods ✅', function () {
    it('should place votes on behalf of a managed vault', async function () {
      const prevotePendingAmount = new BigNumber(
        await (
          await this.election.getPendingVotesForGroupByAccount(this.group, this.persistentVaultInstance.address)
        ).call()
      );

      await this.persistentVoteManagerInstance.vote(
        this.persistentVaultInstance.address,
        this.group,
        this.defaultVotes,
        this.lesser,
        this.greater
      );

      const postvotePendingAmount = new BigNumber(
        await (
          await this.election.getPendingVotesForGroupByAccount(this.group, this.persistentVaultInstance.address)
        ).call()
      );

      return assert.isTrue(
        prevotePendingAmount.plus(this.defaultVotes).isEqualTo(postvotePendingAmount),
        `Expected ${prevotePendingAmount.plus(this.defaultVotes).toFixed(0)} pending votes`
      );
    });

    it('should revoke pending votes on behalf of a managed vault', async function () {
      const prerevokePendingAmount = new BigNumber(
        await (
          await this.election.getPendingVotesForGroupByAccount(this.group, this.persistentVaultInstance.address)
        ).call()
      );
      const accountGroups = await (
        await this.election.getGroupsVotedForByAccount(this.persistentVaultInstance.address)
      ).call();

      await this.persistentVoteManagerInstance.revokePending(
        this.persistentVaultInstance.address,
        this.group,
        this.defaultVotes,
        this.lesser,
        this.greater,
        accountGroups.indexOf(this.group)
      );

      const postrevokePendingAmount = new BigNumber(
        await (
          await this.election.getPendingVotesForGroupByAccount(this.group, this.persistentVaultInstance.address)
        ).call()
      );

      return assert.isTrue(
        prerevokePendingAmount.minus(this.defaultVotes).isEqualTo(postrevokePendingAmount),
        `Expected ${prerevokePendingAmount.minus(this.defaultVotes).toFixed(0)} pending votes`
      );
    });
  });

  describe('Methods 🛑', function () {
    it('should not allow non-owner to initiate voting', async function () {
      return assert.isRejected(
        this.persistentVoteManagerInstance.vote(
          this.persistentVaultInstance.address,
          this.group,
          this.defaultVotes,
          this.lesser,
          this.greater,
          { from: this.secondarySender }
        )
      );
    });

    it('should not place votes for non-managed vault', async function () {
      return assert.isRejected(
        this.persistentVoteManagerInstance.vote(
          this.vaultInstance.address,
          this.group,
          this.defaultVotes,
          this.lesser,
          this.greater
        )
      );
    });

    it('should not allow non-owner to initiate pending votes revoking', async function () {
      return assert.isRejected(
        this.persistentVoteManagerInstance.vote(
          this.persistentVaultInstance.address,
          this.group,
          this.defaultVotes,
          this.lesser,
          this.greater,
          { from: this.secondarySender }
        )
      );
    });

    it('should not revoke pending votes for non-managed vault', async function () {
      return assert.isRejected(
        this.persistentVoteManagerInstance.vote(
          this.vaultInstance.address,
          this.group,
          this.defaultVotes,
          this.lesser,
          this.greater
        )
      );
    });
  });
});
