// contracts/Voting.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../Bank.sol";
import "../Vault.sol";

contract Proposals {
    using SafeMath for uint256;

    struct Proposal {
        // The accounts that have upvoted the proposal
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
        uint256 upvoteCycle;
    }

    Bank public bank;
    Proposal[] public proposals;
    mapping(address => Upvoter) public upvoters;

    // Minimum vault balance required to submit a proposal
    uint256 public proposerBalanceMinimum;
    uint256 public currentProposalCycle;
    uint256 public leadingProposalID;

    // Checks whether a proposal exists for the ID
    function isProposal(uint256 proposalID) public view returns (bool) {
        return proposals[proposalID].upvotes > 0;
    }

    // Checks whether an account is an upvoter in the current cycle
    function _isUpvoterInCurrentCycle(address account, uint256 currentCycle)
        internal
        view
        returns (bool)
    {
        return upvoters[account].upvoteCycle == currentCycle;
    }

    /**
     * @notice Gets the upvotes of a vault owner
     * @param vault Vault
     */
    function getUpvotesForVaultOwner(Vault vault)
        internal
        view
        returns (uint256)
    {
        uint256 upvotes = bank.balanceOf(address(vault));
        require(msg.sender == vault.owner(), "Not vault owner");
        require(upvotes > 0, "Vault has a balance of zero");
        return upvotes;
    }

    function getProposal(uint256 proposalID)
        public
        view
        returns (
            uint256,
            address[] memory,
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        require(proposalID < proposals.length, "Invalid proposal");
        Proposal memory proposal = proposals[proposalID];
        return (
            proposalID,
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
            uint256,
            address[] memory,
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        return getProposal(upvoters[upvoter].proposalID);
    }

    /**
     * @notice Sets a proposal as the leading proposal if it has the most upvotes
     * @param proposalID Proposal index
     */
    function _updateLeadingProposal(uint256 proposalID) internal {
        uint256 proposalUpvotes = proposals[proposalID].upvotes;
        uint256 leadingProposalUpvotes = proposals[leadingProposalID].upvotes;

        if (proposalUpvotes > leadingProposalUpvotes) {
            leadingProposalID = proposalID;
        }
    }

    /**
     * @notice Submits a proposal
     * @param vault Vault
     * @param groupIndexes List of eligible Celo election group indexes
     * @param groupAllocations Percentage of total votes allocated for the groups
     * @param currentCycle The current cycle
     * @dev The allocation for a group is based on its index in groupIndexes
     */
    function _submitProposal(
        Vault vault,
        uint256[] memory groupIndexes,
        uint256[] memory groupAllocations,
        uint256 currentCycle
    ) internal {
        uint256 upvotes = getUpvotesForVaultOwner(vault);
        require(upvotes >= proposerBalanceMinimum, "Insufficient upvotes");
        require(
            _isUpvoterInCurrentCycle(msg.sender, currentCycle) == false,
            "Already an upvoter"
        );

        address[] memory proposalUpvoters;
        uint256 proposalID = proposals.length;
        proposals.push(
            Proposal(proposalUpvoters, upvotes, groupIndexes, groupAllocations)
        );
        proposals[proposalID].upvoters.push(msg.sender);
        upvoters[msg.sender] = Upvoter(upvotes, proposalID, currentCycle);

        _updateLeadingProposal(proposalID);
    }

    /**
     * @notice Adds upvotes to a proposal
     * @param vault Vault
     * @param proposalID Proposal index
     * @param currentCycle The current cycle
     */
    function _addProposalUpvotes(
        Vault vault,
        uint256 proposalID,
        uint256 currentCycle
    ) internal {
        require(isProposal(proposalID), "Invalid proposal");
        require(
            _isUpvoterInCurrentCycle(msg.sender, currentCycle) == false,
            "Already an upvoter"
        );

        // Create a new upvoter and update the proposal
        uint256 upvotes = getUpvotesForVaultOwner(vault);
        upvoters[msg.sender] = Upvoter(upvotes, proposalID, currentCycle);
        Proposal storage proposal = proposals[proposalID];
        proposal.upvoters.push(msg.sender);
        proposal.upvotes = proposal.upvotes.add(upvotes);

        _updateLeadingProposal(proposalID);
    }

    /**
     * @notice Updates the upvotes for an upvoter's proposal
     * @param vault Vault
     * @param currentCycle The current cycle
     */
    function _updateProposalUpvotes(Vault vault, uint256 currentCycle)
        internal
    {
        require(
            _isUpvoterInCurrentCycle(msg.sender, currentCycle),
            "Not an upvoter in current cycle"
        );

        Upvoter storage upvoter = upvoters[msg.sender];

        // Difference between the current and previous vault balances
        uint256 newUpvotes = getUpvotesForVaultOwner(vault);
        uint256 upvoteDifference = newUpvotes.sub(upvoter.upvotes);

        if (upvoteDifference == 0) {
            return;
        }

        // Add the difference to the proposal's upvotes and update the upvoter
        Proposal storage proposal = proposals[upvoter.proposalID];
        proposal.upvotes = proposal.upvotes.add(upvoteDifference);
        upvoter.upvotes = newUpvotes;
        upvoter.upvoteCycle = currentCycle;

        _updateLeadingProposal(upvoter.proposalID);
    }
}
