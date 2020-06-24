pragma solidity ^0.5.8;

import "../Vault.sol";

contract MockVault is Vault {
    using SafeMath for uint256;
    using LinkedList for LinkedList.List;

    function setLocalActiveVotesForGroup(address group, uint256 amount) public {
        activeVotes[group] = amount;
    }

    function setActiveVotesWithoutRewardsForGroup(address group, uint256 amount)
        public
    {
        groupActiveVotesWithoutRewards[group] = amount;
    }

    function setCommission(uint256 percentage) public {
        managerCommission = percentage;
    }

    function setManagerMinimumFunds(uint256 minimumBalance) public {
        managerMinimumFunds = minimumBalance;
    }

    function getVotedGroups() public view returns (address[] memory) {
        address[] memory groups = _getGroupsVoted();
        return groups;
    }

    // function reset() external {
    //     // Reset group related data
    //     address[] memory groups = _getGroupsVoted();
    //     for (uint256 i = 0; i < groups.length; i = i.add(1)) {
    //         delete groupActiveVotesWithoutRewards[groups[i]];
    //     }
    // }
}
