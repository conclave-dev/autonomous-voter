const { newKit } = require('@celo/contractkit');
const { assert } = require('./setup');
const { localRpcAPI, groupMaximum } = require('../../config');

describe.only('Portfolio', function () {
  before(async function () {
    this.election = await newKit(localRpcAPI).contracts.getElection();
  });

  describe('State', function () {
    it('should have a valid election', async function () {
      return assert.equal(this.election.address, await this.portfolio.election());
    });

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

      await this.portfolio.manageVault(this.vaultInstance.address);

      const currentTail = (await this.portfolio.vaults()).tail.substring(0, 42);

      assert.notEqual(initialTail, lowerCaseVaultAddress);
      return assert.equal(currentTail, lowerCaseVaultAddress);
    });
  });

  describe('Methods 🛑', function () {
    it('should not add vault to Portfolio if not vault owner', function () {
      return assert.isRejected(
        this.portfolio.manageVault(this.vaultInstance.address, {
          from: this.secondarySender
        })
      );
    });
  });
});
