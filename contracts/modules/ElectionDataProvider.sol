pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../celo/governance/interfaces/IElection.sol";

contract ElectionDataProvider is Initializable {
    using SafeMath for uint256;

    IElection election;

    function initialize(IElection election_) internal initializer {
        election = election_;
    }

    function findLesserAndGreater(
        address group,
        uint256 votes,
        bool isRevoke
    ) public view returns (address, address) {
        address[] memory groups;
        uint256[] memory groupVotes;
        (groups, groupVotes) = election
            .getTotalVotesForEligibleValidatorGroups();
        address lesser = address(0);
        address greater = address(0);

        // Get the current totalVotes count for the specified group
        uint256 totalVotes = election.getTotalVotesForGroupByAccount(
            group,
            address(this)
        );
        if (isRevoke) {
            totalVotes = totalVotes.sub(votes);
        } else {
            totalVotes = totalVotes.add(votes);
        }

        // Look for the adjacent groups with less and more votes, respectively
        for (uint256 i = 0; i < groups.length; i++) {
            if (groups[i] != group) {
                if (groupVotes[i] <= totalVotes) {
                    lesser = groups[i];
                    break;
                }
                greater = groups[i];
            }
        }

        return (lesser, greater);
    }
}
