// contracts/Voting.sol
pragma solidity ^0.5.8;

contract MProposals {
    struct Proposal {
        // The account that submitted the proposal.
        address proposer;
        // The accounts that support the proposal.
        address[] supporters;
        // Indexes which reference eligible Celo groups
        uint256[] groupIndexes;
        // Vote allocations for groups in `groupIndexes`
        // Group-allocation associations are index-based
        // E.g. groupAllocations[0] for groupIndexes[0],
        // groupAllocations[1] for groupIndexes[1], etc.
        uint256[] groupAllocations;
    }

    // Accounts that support the proposals being voted on (includes proposers)
    struct Supporter {
        // The supporter's vault balance will applied to the proposal's upvotes
        address vault;
        uint256 proposalID;
    }

    Proposal[] proposals;
    mapping(address => Supporter) supporters;

    /**
     * @notice Submits a proposal
     * @param groupIndexes List of eligible Celo election group indexes
     * @param groupAllocations Percentage of total votes allocated for the groups
     * @dev The allocation for a group is based on its index in groupIndexes
     */
    function _submit(
        uint256[] memory groupIndexes,
        uint256[] memory groupAllocations
    ) internal {
        require(
            groupIndexes.length == groupAllocations.length,
            "Index and allocation arrays must be of equal length"
        );

        Supporter storage supporter = supporters[msg.sender];

        // Check whether `msg.sender` already supports a proposal
        if (supporter.vault != address(0)) {
            // Check whether the supporter is also the proposer
            // NOTE: Supporters who are not proposers (i.e. "upvoters")
            // Cannot submit proposals
            require(
                proposals[supporter.proposalID].proposer == msg.sender,
                "Upvoters cannot submit proposals"
            );

            // Delete the proposer's existing proposal and submit new one
            delete proposals[supporter.proposalID];
        }

        address[] memory proposalSupporters;

        proposals.push(
            Proposal(
                msg.sender,
                proposalSupporters,
                groupIndexes,
                groupAllocations
            )
        );
        supporter.proposalID = proposals.length - 1;
    }
}
