const { newKit } = require('@celo/contractkit');
const BigNumber = require('bignumber.js');
const { every } = require('lodash');
const { assert } = require('./setup');
const { localRpcAPI } = require('../../config');

describe('Portfolio', function () {
  before(async function () {
    const kit = newKit(localRpcAPI);

    this.election = await kit.contracts.getElection();

    // Setting cycle parameters in `before` to test cycle-related state
    this.genesisBlockNumber = (await kit.web3.eth.getBlockNumber()) + 1;
    this.cycleBlockDuration = 17280 * 7; // 7 epochs
    this.groupLimit = 3;
    this.proposerMinimum = 10;
    this.validProposalSubmission = {
      indexes: [0, 1, 2],
      allocations: [20, 20, 60]
    };

    await this.portfolio.setCycleParameters(this.genesisBlockNumber, this.cycleBlockDuration);
    await this.portfolio.setProposalsParameters(this.bank.address, this.groupLimit, this.proposerMinimum);
  });

  describe('State', function () {
    it('should set genesisBlockNumber', async function () {
      return assert.equal(this.genesisBlockNumber, await this.portfolio.genesisBlockNumber());
    });

    it('should set blockDuration', async function () {
      return assert.equal(this.cycleBlockDuration, await this.portfolio.blockDuration());
    });

    it('should set proposalGroupLimit', async function () {
      return assert.equal(this.groupLimit, await this.portfolio.proposalGroupLimit());
    });

    it('should set proposerBalanceMinimum', async function () {
      return assert.equal(this.proposerMinimum, await this.portfolio.proposerBalanceMinimum());
    });

    it('should set bank and election contracts', async function () {
      const bank = await this.portfolio.bank();
      const election = await this.portfolio.election();

      assert.equal(bank, this.bank.address);
      return assert.equal(election, this.election.address);
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
        value: new BigNumber(this.proposerMinimum)
      });

      await this.portfolio.submitProposal(
        this.vaultInstance.address,
        this.validProposalSubmission.indexes,
        this.validProposalSubmission.allocations
      );

      const {
        0: upvoters,
        1: upvotes,
        2: groupIndexes,
        3: groupAllocations
      } = await this.portfolio.getProposalByUpvoter(this.primarySender);
      const vaultBalance = await this.bank.balanceOf(this.vaultInstance.address);

      assert.equal(this.primarySender, upvoters[0]);
      assert.equal(vaultBalance, upvotes.toNumber());
      assert.isTrue(every(this.validProposalSubmission.indexes, (val, i) => val === groupIndexes[i].toNumber()));
      return assert.isTrue(
        every(this.validProposalSubmission.allocations, (val, i) => val === groupAllocations[i].toNumber())
      );
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
  });
});
