pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../celo/governance/interfaces/IElection.sol";
import "../celo/common/libraries/UsingPrecompiles.sol";

contract ElectionDataProvider is Initializable, UsingPrecompiles {
    using SafeMath for uint256;

    // Frequently-accessed Celo election data
    struct ElectionGroups {
        uint256 epoch;
        mapping(address => uint256) indexesByAddress;
        mapping(uint256 => address) addressesByIndex;
    }

    IElection election;
    ElectionGroups internal electionGroups;

    function initialize(IElection election_) internal initializer {
        election = election_;
    }

    function _findLesserAndGreater(
        address group,
        uint256 votes,
        bool isRevoke
    ) internal view returns (address, address) {
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

    /**
     * @notice Sets the eligible Celo election groups for the current epoch
     */
    function _updateElectionGroups() internal {
        uint256 epochNumber = getEpochNumber();

        if (epochNumber != electionGroups.epoch) {
            // Reset electionGroups
            delete electionGroups;

            electionGroups.epoch = epochNumber;

            address[] memory eligibleValidatorGroups = election
                .getEligibleValidatorGroups();

            for (uint256 i = 0; i < eligibleValidatorGroups.length; i += 1) {
                electionGroups.indexesByAddress[eligibleValidatorGroups[i]] = i;
                electionGroups.addressesByIndex[i] = eligibleValidatorGroups[i];
            }
        }
    }
}
