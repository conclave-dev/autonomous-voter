// contracts/Voting.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../celo/governance/interfaces/IElection.sol";

contract MVoting {
    using SafeMath for uint256;

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

    IElection public election;
    address public manager;

    // Max number of groups for `groupMaximum`
    uint256 public groupMaximum;
    Group[] public voteAllocations;

    /**
     * @notice Sets the interface for the Celo Election contract
     * @param election_ Celo Election address
     */
    function _setElection(IElection election_) internal {
        election = election_;
    }

    /**
     * @notice Sets the max number of groups that can be allocated votes
     * @param max Maximum number
     */
    function _setGroupMaximum(uint256 max) internal {
        groupMaximum = max;
    }

    /**
     * @notice Sets the voting manager
     * @param manager_ Manager address
     */
    function _setManager(address manager_) internal {
        manager = manager_;
    }

    /**
     * @notice Sets the allocation for Celo election groups
     * @param groupIndexes Indexes of groups (based on Celo ordering)
     * @param allocations # of votes allocated for a group
     * @dev The indexes and allocations
     */
    function _setGroupAllocations(
        uint256[] memory groupIndexes,
        uint256[] memory allocations
    ) internal {
        require(
            groupIndexes.length < groupMaximum,
            "Exceeds max groups allowed"
        );
        require(
            groupIndexes.length == allocations.length,
            "Mismatched indexes and allocations"
        );

        // Reset `voteAllocations`
        delete voteAllocations;

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

            voteAllocations.push(Group(groupIndexes[i], allocations[i], 0));

            // Track allocation total to validate amount is correct
            newAllocationTotal = newAllocationTotal.add(allocations[i]);
        }

        // Require newAllocationTotal fully allocates votes
        require(newAllocationTotal == 100, "Group allocations must be 100");
    }
}
