pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./celo/common/UsingRegistry.sol";
import "./libraries/ElectionDataProvider.sol";
import "./Portfolio.sol";

contract BankVoter is UsingRegistry {
    using SafeMath for uint256;
    using ElectionDataProvider for ElectionDataProvider;

    address manager;

    function initialize(address registry_) public initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Caller is not manager");
        _;
    }

    function setState(address manager_) external onlyOwner {
        manager = manager_;
    }

    /**
     * @notice Revokes votes for a group
     * @param amount Amount of votes to be revoked
     * @param group Group to revoke votes from
     */
    function _revoke(uint256 amount, address group) internal {
        IElection election = getElection();
        uint256 pendingVotes = election.getPendingVotesForGroupByAccount(
            group,
            address(this)
        );
        uint256 activeVotes = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );

        // Revoke pending votes first
        if (pendingVotes > 0) {
            uint256 pendingVotesToRevoke = amount <= pendingVotes
                ? amount
                : pendingVotes;
            (address lesserGroup, address greaterGroup) = ElectionDataProvider
                .findLesserAndGreaterGroups(
                election,
                group,
                address(this),
                pendingVotesToRevoke,
                true
            );

            election.revokePending(
                group,
                amount,
                lesserGroup,
                greaterGroup,
                ElectionDataProvider.findGroupIndexForAccount(
                    election,
                    group,
                    address(this)
                )
            );

            amount = amount.sub(pendingVotesToRevoke);
        }

        // Revoke active votes if pending votes did not cover the revoke amount
        if (amount > 0) {
            (address lesserGroup, address greaterGroup) = ElectionDataProvider
                .findLesserAndGreaterGroups(
                election,
                group,
                address(this),
                amount,
                true
            );

            election.revokeActive(
                group,
                amount,
                lesserGroup,
                greaterGroup,
                ElectionDataProvider.findGroupIndexForAccount(
                    election,
                    group,
                    address(this)
                )
            );

            activeVotes = activeVotes.sub(amount);
        }
    }

    function tidy() external onlyManager {
        IElection election = getElection();
        address[] memory groups = election.getGroupsVotedForByAccount(
            address(this)
        );

        for (uint256 i = 0; i < groups.length; i += 1) {
            address group = groups[i];
            uint256 groupVotes = election.getTotalVotesForGroupByAccount(
                group,
                address(this)
            );
            uint256 proposedGroupVotes = Portfolio(manager)
                .getLeadingProposalGroupVotesForAccount(group, address(this));

            // Revoke all votes for group if it is not within the leading proposal
            if (proposedGroupVotes == 0) {
                _revoke(groupVotes, group);
                continue;
            }

            // Revoke excess votes for groups with more votes than proposed
            if (proposedGroupVotes < groupVotes) {
                _revoke(groupVotes.sub(proposedGroupVotes), group);
            }
        }
    }
}
