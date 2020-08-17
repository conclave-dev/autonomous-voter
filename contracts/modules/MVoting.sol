// contracts/Voting.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../celo/common/libraries/AddressLinkedList.sol";
import "../celo/governance/interfaces/IElection.sol";

contract MVoting {
    using SafeMath for uint256;
    using AddressLinkedList for LinkedList.List;

    struct Group {
        // Index of an eligible Celo election group
        uint256 index;
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

    IElection internal election;
    LinkedList.List public vaults;
    address public manager;

    // Max number of groups for `groupAllocations`
    uint256 public maxGroupAllocations;
    Group[] public groupAllocations;

    /**
     * @notice Sets the interface for the Celo Election contract
     * @param election_ Celo Election address
     */
    function setElection(address election_) internal {
        election = IElection(election_);
    }

    /**
     * @notice Sets the max number of groups that can be allocated votes
     * @param max Maximum number
     */
    function setMaxGroups(uint256 max) internal {
        maxGroupAllocations = max;
    }

    /**
     * @notice Sets the allocation for Celo election groups
     * @param groupIndexes Indexes of groups (based on Celo ordering)
     * @param allocations # of votes allocated for a group
     * @dev The indexes and allocations
     */
    function setGroupAllocations(
        uint256[] memory groupIndexes,
        uint256[] memory allocations
    ) public {
        require(
            groupIndexes.length < maxGroupAllocations,
            "Exceeds max groups allowed"
        );
        require(
            groupIndexes.length == allocations.length,
            "Mismatched indexes and allocations"
        );

        // Reset `groupAllocations`
        delete groupAllocations;

        // Fetch eligible Celo election groups for validation purposes
        (address[] memory groups, ) = election
            .getTotalVotesForEligibleValidatorGroups();

        uint256 newAllocationTotal;

        for (uint256 i = 0; i < groupIndexes.length; i += 1) {
            // TODO: Check whether group index has already been added?
            // Check whether group index references eligible group
            require(
                groupIndexes[i] < groups.length,
                "Eligible group does not exist at index"
            );

            groupAllocations.push(Group(groupIndexes[i], allocations[i], 0));

            // Track allocation total to validate amount is correct
            newAllocationTotal = newAllocationTotal.add(allocations[i]);
        }

        // Require newAllocationTotal fully allocates votes
        require(newAllocationTotal == 100, "Group allocations must be 100");
    }
}
