pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./celo/common/UsingRegistry.sol";
import "./celo/common/libraries/AddressLinkedList.sol";
import "./celo/common/libraries/IntegerSortedLinkedList.sol";
import "./Bank.sol";
import "./VaultFactory.sol";
import "./Vault.sol";

contract Portfolio is UsingRegistry {
    using SafeMath for uint256;
    using AddressLinkedList for LinkedList.List;
    using IntegerSortedLinkedList for SortedLinkedList.List;

    Bank public bank;
    // Enables the Portfolio to only add vaults created by a known factory
    VaultFactory public vaultFactory;
    // Minimum balance required to submit or upvote a proposal
    uint256 public minimumUpvoterBalance;
    // Maximum number of groups that can be proposed
    uint256 public maximumProposalGroups;

    struct Proposal {
        // The account that submitted the proposal
        address proposer;
        // The accounts that have upvoted the proposal
        LinkedList.List upvoters;
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

    mapping(address => address) public vaultsByOwner;
    mapping(uint256 => Proposal) proposals;
    SortedLinkedList.List proposalUpvotesByID;
    mapping(address => Upvoter) public upvoters;

    /**
     * @notice Initializes Portfolio contract
     * @param registry_ Celo Registry contract
     */
    function initialize(address registry_) public initializer {
        Ownable.initialize(msg.sender);
        UsingRegistry.initializeRegistry(msg.sender, registry_);
    }

    function setProtocolContracts(Bank bank_, VaultFactory vaultFactory_)
        external
        onlyOwner
    {
        bank = bank_;
        vaultFactory = vaultFactory_;
    }

    function setProtocolParameters(
        uint256 minimumUpvoterBalance_,
        uint256 maximumProposalGroups_
    ) external onlyOwner {
        minimumUpvoterBalance = minimumUpvoterBalance_;
        maximumProposalGroups = maximumProposalGroups_;
    }

    // Sets the vault
    function setVaultByOwner(address owner_, address vault) external {
        require(
            msg.sender == address(vaultFactory),
            "Caller is not the VaultFactory contract"
        );
        require(
            getVaultByOwner(owner_) == address(0),
            "Vault for owner has already been set"
        );
        vaultsByOwner[owner_] = vault;
    }

    function getVaultByOwner(address owner_) public view returns (address) {
        return vaultsByOwner[owner_];
    }

    /**
     * @notice Validates election group index and allocation parameters
     * @param groupIndexes Indexes referencing eligible Celo election groups
     * @param groupAllocations Percentage of total votes allocated to each group
     */
    function _validateProposalGroups(
        uint256[] memory groupIndexes,
        uint256[] memory groupAllocations
    ) internal view {
        require(
            groupIndexes.length <= maximumProposalGroups,
            "Proposal group limit exceeded"
        );
        require(
            groupIndexes.length == groupAllocations.length,
            "Missing group indexes or allocations"
        );

        // Fetch eligible Celo election groups to ensure group indexes are valid
        (address[] memory celoGroupIndexes, ) = getElection()
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

    function getProposalIDsByUpvotes()
        public
        view
        returns (uint256[] memory proposalIDs, uint256[] memory proposalUpvotes)
    {
        return proposalUpvotesByID.getElements();
    }

    // Checks whether an account is an upvoter
    function isUpvoter(address account) public view returns (bool) {
        return upvoters[account].upvotes > 0;
    }

    /**
     * @notice Gets the upvotes of a vault owner
     * @param vault Vault
     */
    function verifyVaultOwnershipAndGetUpvotes(Vault vault)
        internal
        view
        returns (uint256)
    {
        uint256 upvotes = bank.balanceOf(address(vault));
        require(msg.sender == vault.owner(), "Not vault owner");
        require(upvotes >= minimumUpvoterBalance, "Insufficient balance");
        return upvotes;
    }

    // Retrieves a proposal by ID and return its field values
    function getProposal(uint256 proposalID)
        public
        view
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        Proposal memory proposal = proposals[proposalID];
        return (
            proposal.upvotes,
            proposal.groupIndexes,
            proposal.groupAllocations
        );
    }

    // Retrieves a proposal by an upvoter's proposal ID and return its values
    function getProposalByUpvoter(address upvoter)
        public
        view
        returns (
            uint256 upvoterProposalID,
            uint256 upvotes,
            uint256[] memory groupIndexes,
            uint256[] memory groupAllocations
        )
    {
        upvoterProposalID = upvoters[upvoter].proposalID;
        (upvotes, groupIndexes, groupAllocations) = getProposal(
            upvoterProposalID
        );
        return (upvoterProposalID, upvotes, groupIndexes, groupAllocations);
    }

    /**
     * @notice Submits a proposal
     * @param vault Vault
     * @param groupIndexes List of eligible Celo election group indexes
     * @param groupAllocations Percentage of total votes allocated for the groups
     * @param lesserProposalID Proposal with lesser upvotes after upvotes are set
     * @param greaterProposalID Proposal with greater upvotes after upvotes are set
     * @dev Group indexes and allocations have the same indexes for their arrays
     * @dev Set lesser or greater proposal ID to zero if they do not exist
     */
    function addProposal(
        Vault vault,
        uint256[] calldata groupIndexes,
        uint256[] calldata groupAllocations,
        uint256 lesserProposalID,
        uint256 greaterProposalID
    ) external {
        address proposer = msg.sender;
        require(isUpvoter(proposer) == false, "Already an upvoter");

        (uint256[] memory proposalIDs, ) = proposalUpvotesByID.getElements();
        uint256 newProposalUpvotes = verifyVaultOwnershipAndGetUpvotes(vault);
        uint256 newProposalID = proposalIDs.length + 1;

        proposalUpvotesByID.insert(
            newProposalID,
            newProposalUpvotes,
            lesserProposalID,
            greaterProposalID
        );

        // Create a new proposal and upvoter for proposer
        LinkedList.List memory proposalUpvoters;
        proposals[newProposalID] = Proposal(
            proposer,
            proposalUpvoters,
            newProposalUpvotes,
            groupIndexes,
            groupAllocations
        );
        proposals[newProposalID].upvoters.push(proposer);
        upvoters[proposer] = Upvoter(newProposalUpvotes, newProposalID);
    }

    /**
     * @notice Removes a proposal if caller is the proposer
     * @param proposalID Proposal ID
     */
    function removeProposal(uint256 proposalID) external {
        require(
            proposals[proposalID].proposer == msg.sender,
            "Caller is not the proposer"
        );
        delete proposals[proposalID];
        delete upvoters[msg.sender];
        proposalUpvotesByID.remove(proposalID);
    }

    /**
     * @notice Adds upvotes to a proposal
     * @param vault Vault
     * @param proposalID Proposal index
     * @param lesserProposalID Proposal with lesser upvotes after upvotes are added
     * @param greaterProposalID Proposal with greater upvotes after upvotes are added
     * @dev Set lesser or greater proposal ID to zero if they do not exist
     */
    function addProposalUpvotes(
        Vault vault,
        uint256 proposalID,
        uint256 lesserProposalID,
        uint256 greaterProposalID
    ) external {
        Proposal storage proposal = proposals[proposalID];
        Upvoter storage upvoter = upvoters[msg.sender];
        require(proposal.upvotes > 0, "Invalid proposal");
        require(upvoter.upvotes == 0, "Already an upvoter");

        uint256 upvotes = verifyVaultOwnershipAndGetUpvotes(vault);
        upvoter.upvotes = upvotes;
        upvoter.proposalID = proposalID;
        proposal.upvoters.push(msg.sender);
        proposal.upvotes = proposal.upvotes.add(upvoter.upvotes);

        proposalUpvotesByID.update(
            proposalID,
            proposal.upvotes,
            lesserProposalID,
            greaterProposalID
        );
    }

    /**
     * @notice Removes upvotes from a proposal and deletes the upvoter
     * @param proposalID Proposal index
     * @param lesserProposalID Proposal with lesser upvotes after upvotes are removed
     * @param greaterProposalID Proposal with greater upvotes after upvotes are removed
     * @dev Set lesser or greater proposal ID to zero if they do not exist
     */
    function removeProposalUpvotes(
        uint256 proposalID,
        uint256 lesserProposalID,
        uint256 greaterProposalID
    ) external {
        Proposal storage proposal = proposals[proposalID];
        Upvoter memory upvoter = upvoters[msg.sender];
        require(proposal.upvotes > 0, "Invalid proposal");
        require(
            proposal.upvoters.contains(msg.sender),
            "Not an upvoter for proposal"
        );

        proposal.upvoters.remove(msg.sender);
        proposal.upvotes = proposal.upvotes.sub(upvoter.upvotes);
        delete upvoters[msg.sender];

        proposalUpvotesByID.update(
            proposalID,
            proposal.upvotes,
            lesserProposalID,
            greaterProposalID
        );
    }
}
