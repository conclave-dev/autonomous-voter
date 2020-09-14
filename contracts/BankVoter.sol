pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./celo/common/UsingRegistry.sol";
import "./interfaces/IElectionDataProvider.sol";

contract BankVoter is UsingRegistry {
    using SafeMath for uint256;

    IElectionDataProvider electionDataProvider;
    address manager;

    function initialize(address registry_) public initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Caller is not manager");
        _;
    }

    function setState(
        IElectionDataProvider electionDataProvider_,
        address manager_
    ) external onlyOwner {
        electionDataProvider = electionDataProvider_;
        manager = manager_;
    }

    /**
     * @notice Revokes votes for a group
     * @param amount Amount of votes to be revoked
     * @param group Group to revoke votes from
     */
    function revoke(uint256 amount, address group) external onlyManager {
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
            (address lesserGroup, address greaterGroup) = electionDataProvider
                .findLesserAndGreaterGroups(
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
                electionDataProvider.findGroupIndexForAccount(
                    group,
                    address(this)
                )
            );

            amount = amount.sub(pendingVotesToRevoke);
        }

        // Revoke active votes if pending votes did not cover the revoke amount
        if (amount > 0) {
            (address lesserGroup, address greaterGroup) = electionDataProvider
                .findLesserAndGreaterGroups(group, address(this), amount, true);

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
    }
}
