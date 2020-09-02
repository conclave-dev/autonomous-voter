// contracts/Voting.sol
pragma solidity ^0.5.8;

import "../celo/common/libraries/AddressLinkedList.sol";

contract ElectionManager {
    using AddressLinkedList for LinkedList.List;

    // High-level details about the votes managed by the protocol
    struct Votes {
        uint256 total;
        // Number of votes that have been placed overall
        uint256 voted;
    }

    // Details about a group that will receive votes
    struct Group {
        // Index of the eligible Celo election group
        uint256 index;
        // Percent of total votes allocated to the group
        uint256 allocation;
        // Number of votes that have been placed for the group
        uint256 voted;
    }

    Votes public votes;
    mapping(uint256 => Group[]) groups;
    uint256[] public groupCycles;
    LinkedList.List public voters;
    uint256 public minimumVoterBalance;

    /**
     * @notice Adds a voter
     */
    function addVoter() external {
        require(voters.contains(msg.sender) == false, "Account exists");
        voters.push(msg.sender);
    }

    /**
     * @notice Sets the minimum voter balance requirement
     */
    function setMinimumVoterBalance(uint256 min) external {
        minimumVoterBalance = min;
    }

    /**
     * @notice Adds a set of election group and associated cycle to the `groups` mapping
     * @dev It is up to the inheriting contract to validate
     */
    function _setGroups(
        uint256[] memory groupIndexes,
        uint256[] memory groupAllocations,
        uint256 cycle
    ) internal {
        Group[] storage group = groups[cycle];

        for (uint256 i = 0; i < groupIndexes.length; i += 1) {
            group.push(Group(groupIndexes[i], groupAllocations[i], 0));
        }

        groups[cycle] = (group);
        groupCycles.push(cycle);
    }
}
