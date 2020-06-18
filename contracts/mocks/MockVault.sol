// contracts/Vault.sol
pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../Vault.sol";
import "../Archive.sol";
import "../VaultManager.sol";
import "../celo/common/libraries/AddressLinkedList.sol";

contract MockVault is Vault {
    using SafeMath for uint256;
    using AddressLinkedList for LinkedList.List;

    VaultManagers private vaultManagers;
    Votes private votes;

    // For testing purposes
    mapping(address => uint256) public activeVotesWithoutRewards;
    uint256 public rewardSharePercentage;
    bool public initialized;

    function initialize(
        address mockRegistry_,
        Archive archive_,
        address owner_,
        address admin
    ) public payable initializer {
        Vault.initialize(mockRegistry_, archive_, owner_, admin);
        initialized = true;
    }

    function setActiveVotesWithoutRewardsForGroup(address group, uint256 amount)
        public
    {
        votes.activeVotesWithoutRewards[group] = amount;

        // For testing purposes
        activeVotesWithoutRewards[group] = amount;
    }

    function setRewardSharePercentage(uint256 percentage) public {
        vaultManagers.voting.rewardSharePercentage = percentage;

        // For testing purposes
        rewardSharePercentage = percentage;
    }

    function calculateVotingManagerRewards(address group)
        public
        view
        returns (uint256)
    // uint256,
    // uint256
    // uint256
    {
        // uint256 activeVotesForGroup = election.getActiveVotesForGroupByAccount(
        //     group,
        //     address(this)
        // );
        // uint256 activeVotesWithoutRewardsForGroup = votes
        //     .activeVotesWithoutRewards[group];
        // uint256 rewardShare = vaultManagers.voting.rewardSharePercentage;
        uint256 calculation = election
            .getActiveVotesForGroupByAccount(group, address(this))
            .sub(votes.activeVotesWithoutRewards[group])
            .div(100)
            .mul(vaultManagers.voting.rewardSharePercentage);

        return calculation;
        // return (
        //     // activeVotesForGroup,
        //     // activeVotesWithoutRewardsForGroup,
        //     // rewardShare
        //     calculation
        // );
    }
}
