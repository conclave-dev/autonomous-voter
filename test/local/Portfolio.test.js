const { newKit } = require('@celo/contractkit');
const { assert } = require('./setup');
const { localRpcAPI, groupMaximum } = require('../../config');

describe('Portfolio', function () {
  before(async function () {
    this.election = await newKit(localRpcAPI).contracts.getElection();
  });

  describe('State', function () {
    it('should have a valid groupMaximum', async function () {
      return assert.equal(groupMaximum, await this.portfolio.groupMaximum());
    });

    it('should have a manager only if voteAllocations is set', async function () {
      assert.equal(0, (await this.portfolio.voteAllocations).length);
      return assert.equal(this.zeroAddress, await this.portfolio.manager());
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

    it('should set vote allocations if owner', async function () {
      const eligibleGroupIndexes = [0, 1];
      const groupAllocations = [20, 80];

      await this.portfolio.setVoteAllocations(eligibleGroupIndexes, groupAllocations);

      const firstVoteAllocation = await this.portfolio.voteAllocations(eligibleGroupIndexes[0]);
      const secondVoteAllocation = await this.portfolio.voteAllocations(eligibleGroupIndexes[1]);

      assert.equal(firstVoteAllocation.allocation, groupAllocations[0]);
      return assert.equal(secondVoteAllocation.allocation, groupAllocations[1]);
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

    it('should not set vote allocations if non-owner', function () {
      return assert.isRejected(this.portfolio.setVoteAllocations([0], [100], { from: this.secondarySender }));
    });

    it('should not set vote allocations if group indexes exceeds maximum', function () {
      const eligibleGroupIndexes = [0, 1, 2, 3];
      const groupAllocations = [25, 25, 25, 25];

      return assert.isRejected(this.portfolio.setVoteAllocations(eligibleGroupIndexes, groupAllocations));
    });

    it('should not set vote allocations if group indexes and allocations have mismatched lengths', function () {
      const eligibleGroupIndexes = [0, 1];
      const groupAllocations = [100];

      return assert.isRejected(this.portfolio.setVoteAllocations(eligibleGroupIndexes, groupAllocations));
    });
  });
});
