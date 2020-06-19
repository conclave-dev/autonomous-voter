const BigNumber = require('bignumber.js');
const { contracts, kit } = require('./setup');
const { primarySenderAddress, registryContractAddress } = require('../config');

describe.only('AV 2.0 MVP', function () {
  describe('Alice is a Celo token holder and Bob is a Celo developer', function () {
    it('Alice deploys her Vault with an initial deposit of 0.1 CELO', async function () {
      await this.vaultFactory.createInstance(registryContractAddress, {
        value: new BigNumber('1e17')
      });
      const vaults = await this.archive.getVaultsByOwner(primarySenderAddress);
      this.aliceVault = await contracts.Vault.at(vaults.pop());
      console.log(`Alice's Vault contract has the address ${this.aliceVault.address}`);

      console.log(
        `\n\nView Alice's transaction activity here:\nhttps://alfajores-blockscout.celo-testnet.org/address/${this.aliceVault.address}/transactions\n\n`
      );
    });

    it('Bob deploys his VotingManager', async function () {
      await this.vaultManagerFactory.createInstance(
        this.rewardSharePercentage,
        this.minimumManageableBalanceRequirement
      );
      const vaultManagers = await this.archive.getVaultManagersByOwner(primarySenderAddress);
      this.bobVotingManager = await contracts.VotingVaultManager.at(vaultManagers.pop());
      console.log(`Bob's VotingManager contract has the address ${this.bobVotingManager.address}`);
      console.log(
        `\n\nView Bob's transaction activity here:\nhttps://alfajores-blockscout.celo-testnet.org/address/${this.bobVotingManager.address}/transactions\n\n`
      );
    });

    it('Alice deposits 1 CELO', async function () {
      const manageableBalance = new BigNumber(await this.aliceVault.getManageableBalance()).dividedBy(1e18).toFixed();

      console.log(`Alice's vault balance is currently ${manageableBalance} CELO`);

      const deposit = 1e18;

      await this.aliceVault.deposit({
        value: deposit
      });

      const newManageableBalance = new BigNumber(await this.aliceVault.getManageableBalance())
        .dividedBy(1e18)
        .toFixed();

      console.log(`Alice's vault balance is now ${newManageableBalance} CELO`);
    });

    it('Alice allows Voting Manager Bob to manage her Celo votes', async function () {
      await this.aliceVault.setVotingManager(this.bobVotingManager.address);
      const aliceVaultVotingManager = await this.aliceVault.votingManager();
      console.log(`Bob's voting manager address is ${this.bobVotingManager.address}`);
      console.log(`Alice's voting manager's address is ${aliceVaultVotingManager.contractAddress}`);
      console.log(
        `Alice's voting manager is Bob (true/false): ${
          this.bobVotingManager.address === aliceVaultVotingManager.contractAddress
        }`
      );
    });

    it("Bob votes for a Celo validator group with Alice's Vault balance", async function () {
      this.election = (await kit._web3Contracts.getElection()).methods;

      const groupsVotedFor = await (await this.election.getGroupsVotedForByAccount(this.aliceVault.address)).call();
      const groups = (await (await this.election.getTotalVotesForEligibleValidatorGroups()).call())[0];

      // Use the first voted group or select a random eligible group if it doesn't exist
      this.group = groupsVotedFor.length ? groupsVotedFor[0] : groups[Math.floor(Math.random() * groups.length)];
      this.groupIndex = groups.indexOf(this.group);

      // Check if the voting group we are voting for is the last element
      // If it is, then lesser is 0, otherwise, get the index of the adjacent group with less votes
      this.lesser = this.groupIndex === groups.length - 1 ? this.zeroAddress : groups[this.groupIndex + 1];

      // Check if the voting group index is non-zero (i.e. the first element)
      // If it is non-zero, get the index of the adjacent group with more votes, otherwise set to 0
      this.greater = this.groupIndex ? groups[this.groupIndex - 1] : this.zeroAddress;

      console.log(`Bob wants to vote for this validator group: ${this.group}`);
      const manageableBalance = new BigNumber(await this.aliceVault.getManageableBalance());

      console.log(`Alice's Vault balance is ${manageableBalance.dividedBy(1e18).toFixed()} CELO`);

      const prevotePendingAmount = new BigNumber(
        await (await this.election.getPendingVotesForGroupByAccount(this.group, this.aliceVault.address)).call()
      )
        .dividedBy(1e18)
        .toFixed();

      console.log(`Alice's Vault currently has ${prevotePendingAmount} votes for group ${this.group}`);

      await this.bobVotingManager.vote(
        this.aliceVault.address,
        this.group,
        manageableBalance,
        this.lesser,
        this.greater
      );

      const postvotePendingAmount = new BigNumber(
        await (await this.election.getPendingVotesForGroupByAccount(this.group, this.aliceVault.address)).call()
      )
        .dividedBy(1e18)
        .toFixed();

      console.log(`After Bob votes, Alice's Vault now has ${postvotePendingAmount} votes for group ${this.group}`);
      console.log(
        `\n\nVerify that Alice's Vault voted for the group here:\nhttps://alfajores-blockscout.celo-testnet.org/address/${this.aliceVault.address}/celo\n\n`
      );
    });
  });
});
