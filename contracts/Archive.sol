// contracts/Archive.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "celo-monorepo/packages/protocol/contracts/common/UsingPrecompiles.sol";

import "./celo/common/UsingRegistry.sol";
import "./Vault.sol";
import "./Strategy.sol";

contract Archive is Initializable, Ownable, UsingRegistry, UsingPrecompiles {
    using SafeMath for uint256;

    // EpochRewards data is used to calculate an election group's voter rewards
    struct EpochRewards {
        // Block number which epoch rewards data was retrieved at (used for verification)
        uint256 blockNumber;
        // Result from Election's getActiveVotes()
        uint256 activeVotes;
        // Result from EpochRewards's getTargetVoterRewards() (2nd return value)
        uint256 targetVoterRewards;
        // Result from EpochReward's getRewardsMultiplier()
        uint256 rewardsMultiplier;
        mapping(address => GroupEpochRewards) groupEpochRewards;
    }

    struct GroupEpochRewards {
        uint256 activeVotes;
        uint256 slashingMultiplier;
        uint256 score;
    }

    mapping(address => address) public vaults;
    mapping(address => address) public strategies;
    mapping(uint256 => EpochRewards) private epochRewards;

    address public vaultFactory;
    address public strategyFactory;

    modifier onlyVaultFactory() {
        require(msg.sender == vaultFactory, "Sender is not vault factory");
        _;
    }

    modifier onlyStrategyFactory() {
        require(
            msg.sender == strategyFactory,
            "Sender is not strategy factory"
        );
        _;
    }

    function initialize(address _registry) public initializer {
        Ownable.initialize(msg.sender);
        initializeRegistry(msg.sender, _registry);
    }

    function setVaultFactory(address _vaultFactory) public onlyOwner {
        vaultFactory = _vaultFactory;
    }

    function setStrategyFactory(address _strategyFactory) public onlyOwner {
        strategyFactory = _strategyFactory;
    }

    function _isVaultOwner(address _vault, address _account) internal view {
        require(
            Vault(_vault).owner() == _account,
            "Account is not the vault owner"
        );
    }

    function _isStrategyOwner(address _strategy, address _account)
        internal
        view
    {
        require(
            Strategy(_strategy).owner() == _account,
            "Account is not the strategy owner"
        );
    }

    function getVault(address _owner) external view returns (address) {
        return vaults[_owner];
    }

    function getStrategy(address _owner) external view returns (address) {
        return strategies[_owner];
    }

    function setVault(address _vault, address _account)
        public
        onlyVaultFactory
    {
        _isVaultOwner(_vault, _account);

        vaults[_account] = _vault;
    }

    function setStrategy(address _strategy, address _account)
        public
        onlyStrategyFactory
    {
        _isStrategyOwner(_strategy, _account);

        strategies[_account] = _strategy;
    }

    function hasEpochRewards(uint256 _epochNumber) public view returns (bool) {
        // Only checking activeVotes since there wouldn't be voter rewards if it were 0
        return epochRewards[_epochNumber].activeVotes > 0;
    }

    function setEpochRewards(
        uint256 _epochNumber,
        uint256 _blockNumber,
        uint256 _activeVotes,
        uint256 _targetVoterRewards,
        uint256 _rewardsMultiplier
    ) internal returns (EpochRewards storage) {
        require(
            _epochNumber <= getEpochNumberOfBlock(_blockNumber),
            "Invalid epochNumber"
        );

        epochRewards[_epochNumber] = EpochRewards(
            _blockNumber,
            _activeVotes,
            _targetVoterRewards,
            _rewardsMultiplier
        );

        return epochRewards[_epochNumber];
    }

    function _getEpochRewards(uint256 _epochNumber)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            epochRewards[_epochNumber].blockNumber,
            epochRewards[_epochNumber].activeVotes,
            epochRewards[_epochNumber].targetVoterRewards,
            epochRewards[_epochNumber].rewardsMultiplier
        );
    }

    function setCurrentEpochRewards()
        public
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 epochNumber = getEpochNumberOfBlock(block.number);
        EpochRewards storage currentEpochRewards = epochRewards[epochNumber];

        if (hasEpochRewards(epochNumber)) {
            return _getEpochRewards(epochNumber);
        }

        // Retrieve epoch rewards data from protocol contracts
        uint256 activeVotes = getElection().getActiveVotes();
        uint256 targetVoterRewards = getEpochRewards().getTargetVoterRewards();
        uint256 rewardsMultiplier = getEpochRewards().getRewardsMultiplier();

        setEpochRewards(
            epochNumber,
            block.number,
            activeVotes,
            targetVoterRewards,
            rewardsMultiplier
        );

        return (
            block.number,
            currentEpochRewards.activeVotes,
            currentEpochRewards.targetVoterRewards,
            currentEpochRewards.rewardsMultiplier
        );
    }

    // Modified version of calculateGroupEpochScore (link) to calculate the group score (average of its members' score)
    // https://github.com/celo-org/celo-monorepo/blob/baklava/packages/protocol/contracts/governance/Validators.sol#L408
    function calculateGroupMemberScoreAverage(address[] memory _members)
        public
        view
        returns (uint256)
    {
        require(_members.length > 0, "Members array empty");
        uint256 groupScore;
        for (uint256 i = 0; i < _members.length; i = i.add(1)) {
            (, , , uint256 score, ) = getValidators().getValidator(_members[i]);
            groupScore = groupScore.add(score);
        }
        return groupScore.div(_members.length);
    }

    function hasGroupEpochRewards(uint256 _epochNumber, address _group)
        public
        view
        returns (bool)
    {
        return
            epochRewards[_epochNumber].groupEpochRewards[_group].activeVotes >
            0;
    }

    function setGroupEpochRewards(
        uint256 _epochNumber,
        address _group,
        uint256 _activeVotes,
        uint256 _slashingMultiplier,
        uint256 _score
    ) internal returns (EpochRewards storage) {
        require(
            _epochNumber <= getEpochNumberOfBlock(block.number),
            "Invalid epochNumber"
        );
        require(hasEpochRewards(_epochNumber), "Epoch rewards are not set");
        require(
            getValidators().isValidatorGroup(_group),
            "Not a validator group"
        );

        epochRewards[_epochNumber]
            .groupEpochRewards[_group] = GroupEpochRewards(
            _activeVotes,
            _slashingMultiplier,
            _score
        );

        return epochRewards[_epochNumber];
    }

    function getGroupEpochRewards(uint256 _epochNumber, address _group)
        public
        view
        returns (
            uint256,
            address,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            _epochNumber,
            _group,
            epochRewards[_epochNumber].groupEpochRewards[_group].activeVotes,
            epochRewards[_epochNumber].groupEpochRewards[_group]
                .slashingMultiplier,
            epochRewards[_epochNumber].groupEpochRewards[_group].score
        );
    }

    function setCurrentGroupEpochRewards(address _group)
        public
        returns (
            uint256,
            address,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 epochNumber = getEpochNumberOfBlock(block.number);

        // If exists, return existing group epoch rewards to reduce gas for caller
        if (hasGroupEpochRewards(epochNumber, _group)) {
            return getGroupEpochRewards(epochNumber, _group);
        }

        uint256 activeVotes = getElection().getActiveVotesForGroup(_group);
        (
            address[] memory members,
            ,
            ,
            ,
            ,
            uint256 slashingMultiplier,

        ) = getValidators().getValidatorGroup(_group);
        uint256 groupScore = calculateGroupMemberScoreAverage(members);

        if (!hasEpochRewards(epochNumber)) {
            setCurrentEpochRewards();
        }

        EpochRewards storage currentEpochRewards = epochRewards[epochNumber];
        currentEpochRewards.groupEpochRewards[_group] = GroupEpochRewards(
            activeVotes,
            slashingMultiplier,
            groupScore
        );

        return (
            epochNumber,
            _group,
            activeVotes,
            slashingMultiplier,
            groupScore
        );
    }
}
