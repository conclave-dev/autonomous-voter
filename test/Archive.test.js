const { encodeCall } = require('@openzeppelin/upgrades');
const BigNumber = require('bignumber.js');
const { assert, expect, contracts } = require('./setup');
const {
  primarySenderAddress,
  secondarySenderAddress,
  registryContractAddress,
  baklavaRpcAPI,
  defaultGas,
  defaultGasPrice
} = require('../config');

describe('Archive', () => {
  before(async () => {
    this.archive = await contracts.Archive.deployed();
    this.vaultFactory = await contracts.VaultFactory.deployed();
    this.strategyFactory = await contracts.StrategyFactory.deployed();

    const BaklavaArchive = require('@truffle/contract')(require('../build/contracts/Archive.json'));

    BaklavaArchive.setProvider(baklavaRpcAPI);
    BaklavaArchive.defaults({
      from: '0xB950E83464D7BB84e7420e460DEEc2A7ced656aA',
      gas: defaultGas,
      gasPrice: defaultGasPrice
    });

    this.baklavaArchive = await BaklavaArchive.at('0x8733199963eF29b544ec8F116be1039679Df1Ff9');
    this.baklavaKit = require('@celo/contractkit').newKit(baklavaRpcAPI);
  });

  describe('initialize(address registry)', () => {
    it('should initialize with an owner and registry', async () => {
      assert.equal(await this.archive.owner(), primarySenderAddress, 'Owner does not match sender');
      assert.equal(await this.archive.registry(), registryContractAddress, 'Registry was incorrectly set');
    });
  });

  describe('setVaultFactory(address _vaultFactory)', () => {
    it('should not allow a non-owner to set vaultFactory', async () => {
      await expect(
        this.archive.setVaultFactory(this.vaultFactory.address, { from: secondarySenderAddress })
      ).to.be.rejectedWith(Error);
    });

    it('should allow its owner to set vaultFactory', async () => {
      await this.archive.setVaultFactory(this.vaultFactory.address);

      assert.equal(await this.archive.vaultFactory(), this.vaultFactory.address, 'Owner did not set vault factory');
    });
  });

  describe('updateVault(address vault, address proxyAdmin)', () => {
    it('should initialize vault', async () => {
      const { logs: events } = await this.vaultFactory.createInstance(
        encodeCall(
          'initializeVault',
          ['address', 'address', 'address'],
          [registryContractAddress, this.archive.address, primarySenderAddress]
        ),
        {
          value: new BigNumber(1).multipliedBy('1e17')
        }
      );
      const [instanceCreated, , instanceArchived] = events;
      const vault = await contracts.Vault.at(instanceCreated.args[0]);

      assert.equal(await vault.owner(), instanceArchived.args[1], 'Vault was not initialized with correct owner');
    });
  });

  describe('updateStrategy(address strategy, address proxyAdmin)', () => {
    it('should initialize strategy', async () => {
      const rewardSharePercentage = '10';
      const minimumManagedGold = new BigNumber('1e16').toString();

      const { logs: events } = await this.strategyFactory.createInstance(
        encodeCall(
          'initializeStrategy',
          ['address', 'address', 'uint256', 'uint256'],
          [this.archive.address, primarySenderAddress, rewardSharePercentage, minimumManagedGold]
        )
      );
      const [instanceCreated, , instanceArchived] = events;
      const strategy = await contracts.Strategy.at(instanceCreated.args[0]);

      assert.equal(await strategy.owner(), instanceArchived.args[1], 'Strategy was not initialized with correct owner');
    });
  });

  describe('setCurrentEpochRewards()', () => {
    it('should set epoch rewards', async () => {
      const election = await this.baklavaKit._web3Contracts.getElection();
      const epochRewards = await this.baklavaKit._web3Contracts.getEpochRewards();
      const currentBlockNumber = await this.baklavaKit.web3.eth.getBlockNumber();
      const currentEpochNumber = await this.archive.getEpochNumberOfBlock(currentBlockNumber);

      await this.baklavaArchive.setCurrentEpochRewards();

      const {
        0: blockNumberArch,
        1: activeVotesArch,
        2: targetVoterRewardsArch,
        3: rewardsMultiplierArch
      } = await this.baklavaArchive._getEpochRewards(currentEpochNumber);

      const epochNumberArchive = new BigNumber(await this.archive.getEpochNumberOfBlock(blockNumberArch)).toFixed(0);
      const activeVotesArchive = new BigNumber(activeVotesArch).toFixed(0);
      const activeVotes = await (await election.methods.getActiveVotes()).call();
      const targetVoterRewardsArchive = new BigNumber(targetVoterRewardsArch).toFixed(0);
      const targetVoterRewards = new BigNumber(
        await (await epochRewards.methods.getTargetVoterRewards()).call()
      ).toFixed(0);

      // Get rounded number for rewards multiplier as they fluctuate based on gold supplies
      // Necessary, as our test fetches the rewards multiplier at a different block (resulting in different values)
      const rewardsMultiplierArchive = new BigNumber(rewardsMultiplierArch).dividedBy(1e24).toFixed(5);
      const rewardsMultiplier = new BigNumber(await (await epochRewards.methods.getRewardsMultiplier()).call())
        .dividedBy(1e24)
        .toFixed(5);

      assert.equal(epochNumberArchive, currentEpochNumber, 'Invalid epoch number');
      assert.equal(activeVotesArchive, activeVotes, 'Invalid active votes');
      assert.equal(targetVoterRewardsArchive, targetVoterRewards, 'Invalid target voter rewards');
      assert.equal(rewardsMultiplierArchive, rewardsMultiplier, 'Invalid rewards multiplier');
    });
  });

  describe('setCurrentGroupEpochRewards()', () => {
    it('should set group epoch rewards', async () => {
      const election = await this.baklavaKit.contracts.getElection();
      const validators = await this.baklavaKit.contracts.getValidators();
      const currentBlockNumber = await this.baklavaKit.web3.eth.getBlockNumber();
      const currentEpochNumber = await this.archive.getEpochNumberOfBlock(currentBlockNumber);
      const [electedValidator] = await election.getElectedValidators(
        // Subtract 1 to get epoch index
        currentEpochNumber - 1
      );
      const { affiliation: group } = electedValidator;
      const { slashingMultiplier: groupSlashingMultiplier, members } = await validators.getValidatorGroup(group);
      const groupScore = await this.baklavaArchive.calculateGroupMemberScoreAverage(members);

      await this.baklavaArchive.setCurrentGroupEpochRewards(group);

      const {
        0: epochNumber,
        1: address,
        2: activeVotes,
        3: slashingMultiplier,
        4: score
      } = await this.baklavaArchive.getGroupEpochRewards(currentEpochNumber, group);

      // Undo added digit exponential
      // https://github.com/celo-org/celo-monorepo/blob/baklava/packages/protocol/contracts/common/FixidityLib.sol#L27
      const slashingMultiplierBN = new BigNumber(slashingMultiplier);
      slashingMultiplierBN.e = 0;

      assert.equal(new BigNumber(epochNumber).toNumber(), currentEpochNumber, 'Incorrect epoch number');
      assert.equal(address, group, 'Incorrect group address');
      assert.equal(
        new BigNumber(activeVotes).toNumber(),
        (await election.getActiveVotesForGroup(group, currentBlockNumber)).toNumber(),
        'Invalid activeVotes'
      );
      assert.equal(slashingMultiplierBN.toNumber(), groupSlashingMultiplier.toNumber(), 'Invalid slashingMultiplier');
      assert.equal(new BigNumber(score).toNumber(), new BigNumber(groupScore).toNumber(), 'Invalid score');
    });
  });
});
