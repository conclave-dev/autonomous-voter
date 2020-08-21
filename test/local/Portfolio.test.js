const { newKit } = require('@celo/contractkit');
const { assert } = require('./setup');
const { localRpcAPI } = require('../../config');

describe('Portfolio', function () {
  before(async function () {
    const kit = newKit(localRpcAPI);

    this.election = await kit.contracts.getElection();

    // Setting cycle parameters in `before` to test cycle-related state
    this.genesisBlockNumber = (await kit.web3.eth.getBlockNumber()) + 1;
    this.cycleBlockDuration = 17280 * 7; // 7 epochs
    this.maximumVoteAllocationGroups = 3;

    await this.portfolio.setCycleParameters(this.genesisBlockNumber, this.cycleBlockDuration);
    await this.portfolio.setMaximumVoteAllocationGroups(this.maximumVoteAllocationGroups);
  });

  describe('State', function () {
    it('should have the correct maximumVoteAllocationGroups set', async function () {
      return assert.equal(this.maximumVoteAllocationGroups, await this.portfolio.maximumVoteAllocationGroups());
    });

    it('should have the correct genesisBlockNumber set', async function () {
      return assert.equal(this.genesisBlockNumber, await this.portfolio.genesisBlockNumber());
    });

    it('should have the correct blockDuration set', async function () {
      return assert.equal(this.cycleBlockDuration, await this.portfolio.blockDuration());
    });
  });

  describe('Methods ✅', function () {
    it('should add vault to Portfolio if vault owner', async function () {
      const lowerCaseVaultAddress = this.vaultInstance.address.toLowerCase();
      const initialTail = (await this.portfolio.vaults()).tail.substring(0, 42);

      await this.portfolio.addVault(this.vaultInstance.address);

      const currentTail = (await this.portfolio.vaults()).tail.substring(0, 42);

      assert.notEqual(initialTail, lowerCaseVaultAddress);
      return assert.equal(currentTail, lowerCaseVaultAddress);
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

    it('should not set cycle parameters if non-owner', function () {
      return assert.isRejected(
        this.portfolio.setCycleParameters(this.genesisBlockNumber, this.cycleBlockDuration, {
          from: this.secondarySender
        })
      );
    });

    it('should not set cycle parameters if genesis block input is invalid', function () {
      return assert.isRejected(
        this.portfolio.setCycleParameters(0, this.cycleBlockDuration, {
          from: this.secondarySender
        })
      );
    });

    it('should not set cycle parameters if block duration input is invalid', function () {
      return assert.isRejected(
        this.portfolio.setCycleParameters(this.genesisBlockNumber, 0, {
          from: this.secondarySender
        })
      );
    });

    it('should not submit vote allocation proposal if group indexes exceeds maximum', function () {
      const eligibleGroupIndexes = [0, 1, 2, 3];
      const groupAllocations = [25, 25, 25, 25];

      return assert.isRejected(
        this.portfolio.submitVoteAllocationProposal(this.vaultInstance.address, eligibleGroupIndexes, groupAllocations)
      );
    });

    it('should not submit vote allocation proposal if group indexes and allocations have mismatched lengths', function () {
      const eligibleGroupIndexes = [0, 1];
      const groupAllocations = [100];

      return assert.isRejected(
        this.portfolio.submitVoteAllocationProposal(this.vaultInstance.address, eligibleGroupIndexes, groupAllocations)
      );
    });
  });
});
