pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../celo/governance/interfaces/IElection.sol";
import "../interfaces/IElectionDataProvider.sol";

contract ElectionVoter {
    using SafeMath for uint256;

    address manager;

    modifier onlyManager() {
        require(msg.sender == manager, "Caller is not manager");
        _;
    }

    function _setManager(address manager_) internal {
        manager = manager_;
    }

    /**
     * @notice Revokes votes for a group
     * @param amount Amount of votes to be revoked
     * @param group Group to revoke votes from
     */
    function revoke(
        IElection election,
        IElectionDataProvider electionDataProvider,
        uint256 amount,
        address group
    ) external onlyManager returns (uint256 pendingVotes, uint256 activeVotes) {
        pendingVotes = election.getPendingVotesForGroupByAccount(
            group,
            address(this)
        );
        activeVotes = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );
        require(
            amount <= pendingVotes.add(activeVotes),
            "Revoking too many votes"
        );

        // Revoke pending votes first
        if (pendingVotes > 0) {
            uint256 pendingVotesToRevoke = amount <= pendingVotes
                ? amount
                : pendingVotes;
            (address lesserGroup, address greaterGroup) = electionDataProvider
                .findLesserAndGreaterGroups(group, pendingVotesToRevoke, true);

            election.revokePending(
                group,
                amount,
                lesserGroup,
                greaterGroup,
                electionDataProvider.findGroupIndexForAccount(
                    group,
                    address(this)
                )
            );

            amount = amount.sub(pendingVotesToRevoke);
            pendingVotes = pendingVotes.sub(pendingVotesToRevoke);
        }

        // Revoke active votes if pending votes did not cover the revoke amount
        if (amount > 0) {
            (address lesserGroup, address greaterGroup) = electionDataProvider
                .findLesserAndGreaterGroups(group, amount, true);

            election.revokeActive(
                group,
                amount,
                lesserGroup,
                greaterGroup,
                electionDataProvider.findGroupIndexForAccount(
                    group,
                    address(this)
                )
            );

            activeVotes = activeVotes.sub(amount);
        }

        return (pendingVotes, activeVotes);
    }
}
