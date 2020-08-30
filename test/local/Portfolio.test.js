const { every } = require('lodash');
const { assert } = require('./setup');
const { groupLimit, proposerMinimum, cycleBlockDuration } = require('../../config');

describe('Portfolio', function () {
  before(function () {
    this.validProposalSubmission = {
      indexes: [0, 1, 2],
      allocations: [20, 20, 60]
    };
  });

  describe('State', function () {
    it('should have a genesisBlockNumber set', async function () {
      return assert.equal(this.genesisBlockNumber, await this.portfolio.genesisBlockNumber());
    });

    it('should have a blockDuration set', async function () {
      return assert.equal(cycleBlockDuration, await this.portfolio.blockDuration());
    });

    it('should have a proposalGroupLimit set', async function () {
      return assert.equal(groupLimit, await this.portfolio.proposalGroupLimit());
    });

    it('should have a proposerBalanceMinimum set', async function () {
      return assert.equal(proposerMinimum, await this.portfolio.proposerBalanceMinimum());
    });

    it('should have Bank and Celo Election contracts set', async function () {
      const portfolioBank = await this.portfolio.bank();
      const portfolioElection = await this.portfolio.election();
      const election = await this.kit.contracts.getElection();

      assert.equal(portfolioBank, this.bank.address);
      return assert.equal(portfolioElection, election.address);
    });
  });

  describe('Methods ✅', function () {
    it('should add vault if vault owner', async function () {
      const lowerCaseVaultAddress = this.vaultInstance.address.toLowerCase();
      const initialTail = (await this.portfolio.vaults()).tail.substring(0, 42);

      await this.portfolio.addVault(this.vaultInstance.address);

      const currentTail = (await this.portfolio.vaults()).tail.substring(0, 42);

      assert.notEqual(initialTail, lowerCaseVaultAddress);
      return assert.equal(currentTail, lowerCaseVaultAddress);
    });

    it('should submit a proposal', async function () {
      await this.bank.seed(this.vaultInstance.address, {
        value: proposerMinimum
      });

      await this.portfolio.submitProposal(
        this.vaultInstance.address,
        this.validProposalSubmission.indexes,
        this.validProposalSubmission.allocations
      );

      const proposal = await this.portfolio.getProposalByUpvoter(this.primarySender);
      const vaultBalance = await this.bank.balanceOf(this.vaultInstance.address);
      const { 0: id, 1: upvoters, 2: upvotes, 3: groupIndexes, 4: groupAllocations } = proposal;

      this.submittedProposalID = id;

      assert.deepStrictEqual(proposal, await this.portfolio.getProposal(id));
      assert.equal(this.primarySender, upvoters[0]);
      assert.equal(vaultBalance, upvotes.toNumber());
      assert.isTrue(every(this.validProposalSubmission.indexes, (val, i) => val === groupIndexes[i].toNumber()));
      return assert.isTrue(
        every(this.validProposalSubmission.allocations, (val, i) => val === groupAllocations[i].toNumber())
      );
    });

    it('should add upvotes to a proposal', async function () {
      await this.bank.seed(this.secondaryVaultInstance.address, {
        value: proposerMinimum,
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
        value: proposerMinimum,
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
    it('should not add vault if not vault owner', function () {
      return assert.isRejected(
        this.portfolio.addVault(this.vaultInstance.address, {
          from: this.secondarySender
        })
      );
    });

    it('should not set cycle params: non-owner', function () {
      return assert.isRejected(
        this.portfolio.setCycleParameters(this.genesisBlockNumber, this.cycleBlockDuration, {
          from: this.secondarySender
        })
      );
    });

    it('should not set cycle params: invalid genesis', function () {
      return assert.isRejected(
        this.portfolio.setCycleParameters(0, this.cycleBlockDuration, {
          from: this.secondarySender
        })
      );
    });

    it('should not set cycle params: invalid duration', function () {
      return assert.isRejected(
        this.portfolio.setCycleParameters(this.genesisBlockNumber, 0, {
          from: this.secondarySender
        })
      );
    });

    it('should not submit proposal: already upvoter', function () {
      return assert.isRejected(
        this.portfolio.submitProposal(
          this.vaultInstance.address,
          this.validProposalSubmission.indexes,
          this.validProposalSubmission.allocations
        )
      );
    });

    it('should not submit proposal: vault non-owner', function () {
      return assert.isRejected(
        this.portfolio.submitProposal(
          this.vaultInstance.address,
          this.validProposalSubmission.indexes,
          this.validProposalSubmission.allocations,
          {
            from: this.secondarySender
          }
        )
      );
    });

    it('should not submit proposal: exceeds group limit', function () {
      const groupIndexes = [0, 1, 2, 3];
      const groupAllocations = [25, 25, 25, 25];

      return assert.isRejected(
        this.portfolio.submitProposal(this.vaultInstance.address, groupIndexes, groupAllocations)
      );
    });

    it('should not submit proposal: mismatched indexes and allocations', function () {
      const groupIndexes = [0, 1];
      const groupAllocations = [100];

      return assert.isRejected(
        this.portfolio.submitProposal(this.vaultInstance.address, groupIndexes, groupAllocations)
      );
    });

    it('should not submit proposal: total allocation != 100', function () {
      const groupIndexes = [0, 1, 2];
      const groupAllocations = [20, 20, 100];

      return assert.isRejected(
        this.portfolio.submitProposal(this.vaultInstance.address, groupIndexes, groupAllocations)
      );
    });

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

    it('should co-function with Bank to prevent upvoter vault token transfers', async function () {
      if (!(await this.portfolio.isUpvoter(this.primarySender))) {
        await this.bank.seed(this.vaultInstance.address, {
          value: proposerMinimum
        });

        await this.portfolio.submitProposal(
          this.vaultInstance.address,
          this.validProposalSubmission.indexes,
          this.validProposalSubmission.allocations
        );
      }

      const balance = (await this.bank.balanceOf(this.vaultInstance.address)).toNumber();

      return assert.isRejected(
        this.bank.transferFromVault(this.vaultInstance.address, this.primarySender, balance),
        'Caller upvoted a proposal - cannot transfer tokens yet'
      );
    });
  });
});
