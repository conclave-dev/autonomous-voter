pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../celo/governance/interfaces/IElection.sol";

library ElectionDataProvider {
    using SafeMath for uint256;

    function findLesserAndGreaterGroups(
        IElection election,
        address group,
        uint256 votes,
        bool isRevoke
    ) external view returns (address, address) {
        (address[] memory groups, uint256[] memory groupVotes) = election
            .getTotalVotesForEligibleValidatorGroups();
        address lesser = address(0);
        address greater = address(0);

        // Get the current totalVotes count for the specified group
        uint256 totalVotes = election.getTotalVotesForGroup(group);

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

    function findGroupIndexForAccount(
        IElection election,
        address group,
        address account
    ) external view returns (uint256 groupIndex) {
        address[] memory accountGroups = election.getGroupsVotedForByAccount(
            account
        );

        for (uint256 i = 0; i < accountGroups.length; i += 1) {
            if (group == accountGroups[i]) {
                return i;
            }
        }
    }
}
