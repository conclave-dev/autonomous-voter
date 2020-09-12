const { assert } = require('./setup');
const { minimumUpvoterBalance, maximumProposalGroups } = require('../../config');

describe('Portfolio', function () {
  before(function () {
    this.vaultSeedAmount = 100;
    this.validProposalSubmission = {
      indexes: [0, 1, 2],
      allocations: [20, 20, 60]
    };
  });

  describe('State', function () {
    it(`should have a mapping to track user's vault instances`, async function () {
      const primarySenderVaults = await this.portfolio.vaultsByOwner(this.primarySender);
      return assert.isTrue(primarySenderVaults.length > 0);
    });
  });

  describe('Methods ✅', function () {
    it('should initialize with an owner', async function () {
      return assert.equal(await this.portfolio.owner(), this.primarySender);
    });

    it('should have correct protocol parameters set', async function () {
      assert.equal(await this.portfolio.minimumUpvoterBalance(), minimumUpvoterBalance);
      return assert.equal(await this.portfolio.maximumProposalGroups(), maximumProposalGroups);
    });

    it('should get a vault by owner', async function () {
      return assert.equal(await this.portfolio.vaultsByOwner(this.primarySender), this.vaultInstance.address);
    });

    it('should submit a proposal', async function () {
      await this.bank.seed(this.vaultInstance.address, {
        value: this.vaultSeedAmount
      });

      await this.portfolio.addProposal(
        this.vaultInstance.address,
        this.validProposalSubmission.indexes,
        this.validProposalSubmission.allocations,
        0,
        0
      );

      const proposalID = (await this.portfolio.upvoters(this.primarySender)).proposalID.toNumber();
      const { upvotes } = await this.portfolio.getProposal(proposalID);
      const vaultBalance = await this.bank.balanceOf(this.vaultInstance.address);

      this.submittedProposalID = proposalID;

      return assert.equal(upvotes.toNumber(), vaultBalance.toNumber());
    });
  });

  describe('Methods 🛑', function () {
    it('should not add upvotes to a proposal: not vault owner', function () {
      return assert.isRejected(
        this.portfolio.addProposalUpvotes(this.secondaryVaultInstance.address, this.submittedProposalID, {
          from: this.primarySender
        })
      );
    });

    it('should not add upvotes to a proposal: invalid proposal ID', function () {
      return assert.isRejected(
        this.portfolio.addProposalUpvotes(this.secondaryVaultInstance.address, this.submittedProposalID + 100, {
          from: this.secondarySender
        })
      );
    });
  });
});
