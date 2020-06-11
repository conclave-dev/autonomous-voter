// contracts/Archive.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "celo-monorepo/packages/protocol/contracts/common/UsingPrecompiles.sol";

import "./celo/common/UsingRegistry.sol";
import "./Vault.sol";
import "./VaultManager.sol";

contract Archive is Initializable, Ownable, UsingRegistry, UsingPrecompiles {
    using AddressLinkedList for LinkedList.List;
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

    mapping(address => LinkedList.List) public vaultOwners;
    mapping(address => LinkedList.List) public vaultManagerOwners;
    mapping(uint256 => EpochRewards) private epochRewards;

    address public vaultFactory;
    address public vaultManagerFactory;

    modifier onlyVaultFactory() {
        require(msg.sender == vaultFactory, "Sender is not vault factory");
        _;
    }

    modifier onlyVaultManagerFactory() {
        require(
            msg.sender == vaultManagerFactory,
            "Not the vault manager factory"
        );
        _;
    }

    function initialize(address registry_) public initializer {
        Ownable.initialize(msg.sender);

        // registry_ has a trailing underscore to avoid collision with inherited prop from UsingRegistry
        initializeRegistry(msg.sender, registry_);
    }

    function setVaultFactory(address vaultFactory_) public onlyOwner {
        vaultFactory = vaultFactory_;
    }

    function setVaultManagerFactory(address vaultManagerFactory_)
        public
        onlyOwner
    {
        vaultManagerFactory = vaultManagerFactory_;
    }

    function _isVaultOwner(address vault, address owner_) internal view {
        require(
            Vault(vault).owner() == owner_,
            "Account is not the vault owner"
        );
    }

    function _isVaultManagerOwner(address vaultManager, address owner_)
        internal
        view
    {
        require(
            VaultManager(vaultManager).owner() == owner_,
            "Account is not the vaultManager owner"
        );
    }

    function getVaultOwner(address owner_)
        external
        view
        returns (address[] memory)
    {
        return vaultOwners[owner_].getKeys();
    }

    function getVaultManagerOwner(address owner_)
        external
        view
        returns (address[] memory)
    {
        return vaultManagerOwners[owner_].getKeys();
    }

    function associateVaultWithOwner(address vault, address owner_)
        public
        onlyVaultFactory
    {
        require(
            !vaultOwners[owner_].contains(vault),
            "Vault has already been set"
        );
        vaultOwners[owner_].push(vault);
    }

    function associateVaultManagerWithOwner(
        address vaultManager,
        address owner_
    ) public onlyVaultManagerFactory {
        require(
            !vaultManagerOwners[owner_].contains(vaultManager),
            "VaultManager has already been set"
        );
        vaultManagerOwners[owner_].push(vaultManager);
    }

    function hasEpochRewards(uint256 epochNumber) public view returns (bool) {
        // Only checking activeVotes since there wouldn't be voter rewards if it were 0
        return epochRewards[epochNumber].activeVotes > 0;
    }

    function setEpochRewards(
        uint256 epochNumber,
        uint256 blockNumber,
        uint256 activeVotes,
        uint256 targetVoterRewards,
        uint256 rewardsMultiplier
    ) internal returns (EpochRewards storage) {
        require(
            epochNumber <= getEpochNumberOfBlock(blockNumber),
            "Invalid epochNumber"
        );

        epochRewards[epochNumber] = EpochRewards(
            blockNumber,
            activeVotes,
            targetVoterRewards,
            rewardsMultiplier
        );

        return epochRewards[epochNumber];
    }

    function _getEpochRewards(uint256 epochNumber)
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
            epochRewards[epochNumber].blockNumber,
            epochRewards[epochNumber].activeVotes,
            epochRewards[epochNumber].targetVoterRewards,
            epochRewards[epochNumber].rewardsMultiplier
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
    function calculateGroupMemberScoreAverage(address[] memory members)
        public
        view
        returns (uint256)
    {
        require(members.length > 0, "Members array empty");
        uint256 groupScore;
        for (uint256 i = 0; i < members.length; i = i.add(1)) {
            (, , , uint256 score, ) = getValidators().getValidator(members[i]);
            groupScore = groupScore.add(score);
        }
        return groupScore.div(members.length);
    }

    function hasGroupEpochRewards(uint256 epochNumber, address group)
        public
        view
        returns (bool)
    {
        return
            epochRewards[epochNumber].groupEpochRewards[group].activeVotes > 0;
    }

    function setGroupEpochRewards(
        uint256 epochNumber,
        address group,
        uint256 activeVotes,
        uint256 slashingMultiplier,
        uint256 score
    ) internal returns (EpochRewards storage) {
        require(
            epochNumber <= getEpochNumberOfBlock(block.number),
            "Invalid epochNumber"
        );
        require(hasEpochRewards(epochNumber), "Epoch rewards are not set");
        require(
            getValidators().isValidatorGroup(group),
            "Not a validator group"
        );

        epochRewards[epochNumber].groupEpochRewards[group] = GroupEpochRewards(
            activeVotes,
            slashingMultiplier,
            score
        );

        return epochRewards[epochNumber];
    }

    function getGroupEpochRewards(uint256 epochNumber, address group)
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
            epochNumber,
            group,
            epochRewards[epochNumber].groupEpochRewards[group].activeVotes,
            epochRewards[epochNumber].groupEpochRewards[group]
                .slashingMultiplier,
            epochRewards[epochNumber].groupEpochRewards[group].score
        );
    }

    function setCurrentGroupEpochRewards(address group)
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
        if (hasGroupEpochRewards(epochNumber, group)) {
            return getGroupEpochRewards(epochNumber, group);
        }

        uint256 activeVotes = getElection().getActiveVotesForGroup(group);
        (
            address[] memory members,
            ,
            ,
            ,
            ,
            uint256 slashingMultiplier,

        ) = getValidators().getValidatorGroup(group);
        uint256 groupScore = calculateGroupMemberScoreAverage(members);

        if (!hasEpochRewards(epochNumber)) {
            setCurrentEpochRewards();
        }

        EpochRewards storage currentEpochRewards = epochRewards[epochNumber];
        currentEpochRewards.groupEpochRewards[group] = GroupEpochRewards(
            activeVotes,
            slashingMultiplier,
            groupScore
        );

        return (
            epochNumber,
            group,
            activeVotes,
            slashingMultiplier,
            groupScore
        );
    }
}
