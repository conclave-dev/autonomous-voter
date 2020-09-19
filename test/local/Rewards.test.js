const BigNumber = require('bignumber.js');
const Promise = require('bluebird');
const { assert } = require('./setup');

describe('Rewards', function () {
  describe('State', function () {
    it('should be a registered Celo account', async function () {
      const accounts = await this.kit.contracts.getAccounts();

      return assert.isTrue(await accounts.isAccount(this.rewards.address));
    });

    it('should have the Portfolio set', async function () {
      return assert.equal(await this.rewards.portfolio(), this.portfolio.address);
    });
  });

  describe('Methods ✅', function () {
    it('should enable the Bank to deposit and lock CELO', async function () {
      const lockedGold = await this.kit.contracts.getLockedGold();
      const seedAmount = 100;
      const lockedGoldBeforeSeed = (await lockedGold.getAccountTotalLockedGold(this.rewards.address)).toNumber();

      await this.bank.seed(this.vaultInstance.address, {
        value: seedAmount
      });

      const lockedGoldAfterSeed = (await lockedGold.getAccountTotalLockedGold(this.rewards.address)).toNumber();

      return assert.equal(lockedGoldBeforeSeed + seedAmount, lockedGoldAfterSeed);
    });

    it('should allow the Portfolio to vote', async function () {
      await this.portfolio.updatePortfolioGroups();

      const election = await this.kit.contracts.getElection();

      await this.portfolio.applyVotes(this.rewards.address);

      const { groups, groupVotePercents } = await this.portfolio.getPortfolioGroups();
      const groupsVoted = await election.getGroupsVotedForByAccount(this.rewards.address);
      const accountVotes = await (await election.contract.methods.getTotalVotesByAccount(this.rewards.address)).call();

      // Check that votes were applied to groups correctly
      const votesApplied = await Promise.map(groups, async (group, i) => {
        const expectedGroupVotes = new BigNumber(Math.floor((accountVotes / 100) * groupVotePercents));
        const actualGroupVotes = new BigNumber(
          await (await election.contract.methods.getTotalVotesForGroupByAccount(group, this.rewards.address)).call()
        );

        return expectedGroupVotes.isEqualTo(actualGroupVotes) && groupsVoted[i].toLowerCase() === group.toLowerCase();
      });

      return assert.isTrue(votesApplied.every((i) => i));
    });
  });

  describe('Methods 🛑', function () {});
});
