// contracts/Voting.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../Bank.sol";
import "../celo/governance/interfaces/IElection.sol";
import "../Vault.sol";

contract MProposals {
    using SafeMath for uint256;

    struct Proposal {
        // The accounts that support the proposal.
        address[] upvoters;
        // The cumulative vault balances of the proposal
        uint256 upvotes;
        // Indexes which reference eligible Celo groups
        uint256[] groupIndexes;
        // Vote allocations for groups in `groupIndexes`
        // Group-allocation associations are index-based
        // E.g. groupAllocations[0] for groupIndexes[0],
        // groupAllocations[1] for groupIndexes[1], etc.
        uint256[] groupAllocations;
    }

    // Accounts that have upvoted a proposal
    struct Upvoter {
        uint256 upvotes;
        uint256 proposalID;
    }

    Bank public bank;
    IElection public election;

    // The maximum number of unique groups that can receive votes
    uint256 public proposalGroupLimit;
    // Minimum proposer vault balance required in order to submit a proposal
    uint256 public proposerBalanceMinimum;

    Proposal[] public proposals;
    mapping(address => Upvoter) public upvoters;

    // Checks whether an account is an upvoter
    function isUpvoter(address account) public view returns (bool) {
        return upvoters[account].upvotes > 0;
    }

    /**
     * @notice Validates a proposal's group indexes and allocations
     * @param groupIndexes Indexes referencing eligible Celo election groups
     * @param groupAllocations Percentage of total votes allocated to each group
     */
    function _validateProposalGroups(
        uint256[] memory groupIndexes,
        uint256[] memory groupAllocations
    ) internal view {
        require(
            groupIndexes.length <= proposalGroupLimit,
            "Proposal group limit exceeded"
        );
        require(
            groupIndexes.length == groupAllocations.length,
            "Missing group indexes or allocations"
        );

        // Fetch eligible Celo election groups to ensure group indexes are valid
        (address[] memory celoGroupIndexes, ) = election
            .getTotalVotesForEligibleValidatorGroups();

        // For validating that the group allocation total is 100
        uint256 groupAllocationTotal;

        for (uint256 i = 0; i < groupIndexes.length; i += 1) {
            uint256 groupIndex = groupIndexes[i];
            uint256 groupAllocation = groupAllocations[i];

            // If not the first iteration, then validate that the current group
            // index is larger than the previous group index.
            require(
                i == 0 || groupIndex > groupIndexes[i - 1],
                "Indexes must be in ascending order without duplicates"
            );
            require(
                groupIndex < celoGroupIndexes.length,
                "Index must be that of an eligible Celo group"
            );
            require(groupAllocation > 0, "Allocation cannot be zero");

            groupAllocationTotal = groupAllocationTotal.add(groupAllocation);
        }

        require(
            groupAllocationTotal == 100,
            "Total group allocation must be 100"
        );
    }

    function getProposal(uint256 proposalID)
        public
        view
        returns (
            address[] memory,
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        require(proposalID < proposals.length, "Invalid proposal ID");
        Proposal memory proposal = proposals[proposalID];
        return (
            proposal.upvoters,
            proposal.upvotes,
            proposal.groupIndexes,
            proposal.groupAllocations
        );
    }

    function getProposalByUpvoter(address upvoter)
        public
        view
        returns (
            address[] memory,
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        require(isUpvoter(upvoter), "Invalid upvoter");
        return getProposal(upvoters[upvoter].proposalID);
    }

    /**
     * @notice Submits a proposal
     * @param vault The caller's vault
     * @param groupIndexes List of eligible Celo election group indexes
     * @param groupAllocations Percentage of total votes allocated for the groups
     * @dev The allocation for a group is based on its index in groupIndexes
     */
    function submitProposal(
        Vault vault,
        uint256[] calldata groupIndexes,
        uint256[] calldata groupAllocations
    ) external {
        require(msg.sender == vault.owner(), "Caller must be vault owner");
        require(isUpvoter(msg.sender) == false, "Caller is already an upvoter");

        uint256 vaultBalance = bank.balanceOf(address(vault));
        require(
            vaultBalance >= proposerBalanceMinimum,
            "Balance does not satisfy the minimum requirement"
        );

        _validateProposalGroups(groupIndexes, groupAllocations);

        address[] memory proposalUpvoters;
        proposals.push(
            Proposal(
                proposalUpvoters,
                vaultBalance,
                groupIndexes,
                groupAllocations
            )
        );
        upvoters[msg.sender] = Upvoter(vaultBalance, proposals.length - 1);
    }

    /**
     * @notice Upvotes a proposal
     * @param vault The caller's vault
     * @param proposalID Index of the proposal
     */
    function upvoteProposal(Vault vault, uint256 proposalID) external {
        require(msg.sender == vault.owner(), "Caller must be vault owner");
        require(isUpvoter(msg.sender) == false, "Caller is already an upvoter");

        Proposal storage proposal = proposals[proposalID];
        require(proposal.upvoters.length > 0, "Invalid proposal");

        uint256 vaultBalance = bank.balanceOf(address(vault));
        require(vaultBalance > 0, "Balance is zero");

        upvoters[msg.sender] = Upvoter(vaultBalance, proposalID);
        proposal.upvoters.push(msg.sender);
        proposal.upvotes = proposal.upvotes.add(vaultBalance);
    }
}
