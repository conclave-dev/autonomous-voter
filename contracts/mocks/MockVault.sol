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
        if (groupsWithActiveVotes.contains(group) == false) {
            groupsWithActiveVotes.push(group);
        }

        groupActiveVotesWithoutRewards[group] = amount;
    }

    function setRewardSharePercentage(uint256 percentage) public {
        votingManager.rewardSharePercentage = percentage;
    }

    function setMinimumManageableBalanceRequirement(uint256 minimumBalance)
        public
    {
        votingManager.minimumManageableBalanceRequirement = minimumBalance;
    }

    function getVotedGroups() public view returns (address[] memory) {
        address[] memory groups = _getGroupsWithActiveVotes();
        return groups;
    }

    function reset() external {
        // Reset group related data
        address[] memory groups = _getGroupsWithActiveVotes();
        for (uint256 i = 0; i < groups.length; i = i.add(1)) {
            groupsWithActiveVotes.remove(groups[i]);
            delete groupActiveVotesWithoutRewards[groups[i]];
        }
    }
}
