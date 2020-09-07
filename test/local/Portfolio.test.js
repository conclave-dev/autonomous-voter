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

      await this.portfolio.submitProposal(
        this.vaultInstance.address,
        this.validProposalSubmission.indexes,
        this.validProposalSubmission.allocations,
        0,
        0
      );

      const { 0: proposalID, 1: upvoters, 2: upvotes } = await this.portfolio.getProposalByUpvoter(this.primarySender);
      const vaultBalance = await this.bank.balanceOf(this.vaultInstance.address);

      this.submittedProposalID = proposalID;

      assert.equal(upvoters.length, 1);
      assert.equal(upvoters[0], this.primarySender);
      return assert.equal(upvotes.toNumber(), vaultBalance.toNumber());
    });

    it('should add upvotes to a proposal', async function () {
      await this.bank.seed(this.secondaryVaultInstance.address, {
        value: this.vaultSeedAmount,
        from: this.secondarySender
      });

      // Get proposal that the secondary sender is planning to upvote, for comparison
      const { 2: oldUpvotes } = await this.portfolio.getProposalByUpvoter(this.primarySender);
      const expectedNewUpvotes =
        (await this.bank.balanceOf(this.secondaryVaultInstance.address)).toNumber() + oldUpvotes.toNumber();

      await this.portfolio.addProposalUpvotes(this.secondaryVaultInstance.address, this.submittedProposalID, {
        from: this.secondarySender
      });

      const { 1: newUpvoters, 2: newUpvotes } = await this.portfolio.getProposalByUpvoter(this.primarySender);

      assert.equal(newUpvoters[newUpvoters.length - 1], this.secondarySender);
      return assert.equal(expectedNewUpvotes, newUpvotes);
    });

    it('should update upvotes for a proposal', async function () {
      const currentUpvotes = (await this.portfolio.upvoters(this.secondarySender)).upvotes.toNumber();
      const currentProposalUpvotes = (await this.portfolio.getProposalByUpvoter(this.primarySender))[2].toNumber();

      // Seed additional tokens for the upvoter
      await this.bank.seed(this.secondaryVaultInstance.address, {
        value: this.vaultSeedAmount,
        from: this.secondarySender
      });
      await this.portfolio.updateProposalUpvotes(this.secondaryVaultInstance.address, {
        from: this.secondarySender
      });

      const updatedUpvotes = (await this.portfolio.upvoters(this.secondarySender)).upvotes.toNumber();
      const updatedProposalUpvotes = (await this.portfolio.getProposalByUpvoter(this.primarySender))[2].toNumber();
      const upvoteDifference = updatedUpvotes - currentUpvotes;

      return assert.equal(currentProposalUpvotes + upvoteDifference, updatedProposalUpvotes);
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

    it('should not update upvotes for a proposal: not vault owner', function () {
      return assert.isRejected(
        this.portfolio.updateProposalUpvotes(this.secondaryVaultInstance.address, {
          from: this.primarySender
        })
      );
    });
  });
});
