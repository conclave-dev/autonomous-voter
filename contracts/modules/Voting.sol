// contracts/Voting.sol
pragma solidity ^0.5.8;

import "../celo/common/libraries/AddressLinkedList.sol";

contract VoteManagement {
    using AddressLinkedList for LinkedList.List;

    struct Group {
        // Percentage of the total votes
        uint256 allocation;
        // # of votes received
        uint256 received;
    }

    struct Votes {
        uint256 total;
        // # of votes placed
        uint256 placed;
    }

    Group[] groupAllocations;
    LinkedList.List public vaults;
    address manager;

    /**
     * @notice Sets the allocation for Celo election groups
     * @param groupIndexes Indexes of groups (based on Celo ordering)
     * @param allocations # of votes allocated for a group
     * @dev The indexes and allocations
     */
    function setGroupAllocations(
        uint256[] calldata groupIndexes,
        uint256[] calldata allocations
    ) external {}
}
