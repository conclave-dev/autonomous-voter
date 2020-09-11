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

    function _findLesserAndGreaterAfterApplyingVotes(
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

    function _findGroupIndexForAccount(address group, address account)
        internal
        view
        returns (uint256 groupIndex)
    {
        address[] memory accountGroups = election.getGroupsVotedForByAccount(
            account
        );

        for (uint256 i = 0; i < accountGroups.length; i += 1) {
            if (group == accountGroups[i]) {
                return i;
            }
        }
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

    /**
     * @notice Revokes votes for a group
     * @param revokeAmount Amount of votes to be revoked
     * @param group Group to revoke votes from
     * @param account Account voting for group
     */
    function _revokeVotes(
        uint256 revokeAmount,
        address group,
        address account
    ) internal returns (uint256 pendingVotes, uint256 activeVotes) {
        pendingVotes = election.getPendingVotesForGroupByAccount(
            group,
            account
        );
        activeVotes = election.getActiveVotesForGroupByAccount(group, account);
        require(
            revokeAmount <= pendingVotes.add(activeVotes),
            "Revoking too many votes"
        );

        // Revoke pending votes first
        if (pendingVotes > 0) {
            uint256 pendingVotesToRevoke = revokeAmount <= pendingVotes
                ? revokeAmount
                : pendingVotes;
            (
                address lesserGroup,
                address greaterGroup
            ) = _findLesserAndGreaterAfterApplyingVotes(
                group,
                pendingVotesToRevoke,
                true
            );

            election.revokePending(
                group,
                revokeAmount,
                lesserGroup,
                greaterGroup,
                _findGroupIndexForAccount(group, account)
            );

            revokeAmount = revokeAmount.sub(pendingVotesToRevoke);
            pendingVotes = pendingVotes.sub(pendingVotesToRevoke);
        }

        // Revoke active votes if pending votes did not cover the revoke amount
        if (revokeAmount > 0) {
            (
                address lesserGroup,
                address greaterGroup
            ) = _findLesserAndGreaterAfterApplyingVotes(
                group,
                revokeAmount,
                true
            );

            election.revokeActive(
                group,
                revokeAmount,
                lesserGroup,
                greaterGroup,
                _findGroupIndexForAccount(group, account)
            );

            activeVotes = activeVotes.sub(revokeAmount);
        }

        return (pendingVotes, activeVotes);
    }
}
