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
      const primarySenderVaults = await this.portfolio.getVaultByOwner(this.primarySender);
      return assert.isTrue(primarySenderVaults.length > 0);
    });
  });

  describe('Methods ✅', function () {
    it('should initialize with an owner', async function () {
      return assert.equal(await this.portfolio.owner(), this.primarySender);
    });

    it('should have correct protocol contracts set', async function () {
      assert.equal(await this.portfolio.registry(), this.registryContractAddress);
      assert.equal(await this.portfolio.bank(), this.bank.address);
      return assert.equal(await this.portfolio.vaultFactory(), this.vaultFactory.address);
    });

    it('should have correct protocol parameters set', async function () {
      assert.equal(await this.portfolio.minimumUpvoterBalance(), minimumUpvoterBalance);
      return assert.equal(await this.portfolio.maximumProposalGroups(), maximumProposalGroups);
    });

    it('should get a vault by owner', async function () {
      return assert.equal(await this.portfolio.getVaultByOwner(this.primarySender), this.vaultInstance.address);
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

      const { 0: proposalID, 1: upvotes } = await this.portfolio.getProposalByUpvoter(this.primarySender);
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
