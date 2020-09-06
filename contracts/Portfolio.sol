pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./celo/common/UsingRegistry.sol";
import "./Bank.sol";
import "./VaultFactory.sol";
import "./Vault.sol";

contract Portfolio is UsingRegistry {
    using SafeMath for uint256;

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

    mapping(address => address) public vaultsByOwner;
    Proposal[] public proposals;
    uint256 public leadingProposalID;
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

    // Checks whether a proposal exists for the ID
    function isProposal(uint256 proposalID) public view returns (bool) {
        return proposals[proposalID].upvotes > 0;
    }

    // Checks whether an account is an upvoter
    function isUpvoter(address account) public view returns (bool) {
        return upvoters[account].upvotes > 0;
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
        require(upvotes > minimumUpvoterBalance, "Insufficient balance");
        return upvotes;
    }

    // Retrieves a proposal by ID and return its field values
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
        require(proposalID < proposals.length, "Invalid proposal");
        Proposal memory proposal = proposals[proposalID];
        return (
            proposal.upvoters,
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
            address[] memory proposalUpvoters,
            uint256 upvotes,
            uint256[] memory groupIndexes,
            uint256[] memory groupAllocations
        )
    {
        upvoterProposalID = upvoters[upvoter].proposalID;
        (
            proposalUpvoters,
            upvotes,
            groupIndexes,
            groupAllocations
        ) = getProposal(upvoterProposalID);
        return (
            upvoterProposalID,
            proposalUpvoters,
            upvotes,
            groupIndexes,
            groupAllocations
        );
    }

    /**
     * @notice Submits a proposal
     * @param vault Vault
     * @param groupIndexes List of eligible Celo election group indexes
     * @param groupAllocations Percentage of total votes allocated for the groups
     * @dev The allocation for a group is based on its index in groupIndexes
     */
    function submitProposal(
        Vault vault,
        uint256[] calldata groupIndexes,
        uint256[] calldata groupAllocations
    ) external {
        require(isUpvoter(msg.sender) == false, "Already an upvoter");

        // Compare caller's upvotes with that of the smallest proposal's upvotes
        uint256 upvotes = getUpvotesForVaultOwner(vault);
        uint256 proposalID = proposals.length;
        address[] memory proposalUpvoters;
        proposals.push(
            Proposal(
                msg.sender,
                proposalUpvoters,
                upvotes,
                groupIndexes,
                groupAllocations
            )
        );
        proposals[proposalID].upvoters.push(msg.sender);
        upvoters[msg.sender] = Upvoter(upvotes, proposalID);

        _updateLeadingProposal(proposalID);
    }

    /**
     * @notice Adds upvotes to a proposal
     * @param vault Vault
     * @param proposalID Proposal index
     */
    function addProposalUpvotes(Vault vault, uint256 proposalID) external {
        require(isProposal(proposalID), "Invalid proposal");
        require(isUpvoter(msg.sender) == false, "Already an upvoter");

        // Create a new upvoter and update the proposal
        uint256 upvotes = getUpvotesForVaultOwner(vault);
        upvoters[msg.sender] = Upvoter(upvotes, proposalID);
        Proposal storage proposal = proposals[proposalID];
        proposal.upvoters.push(msg.sender);
        proposal.upvotes = proposal.upvotes.add(upvotes);

        _updateLeadingProposal(proposalID);
    }

    /**
     * @notice Updates the upvotes for an upvoter's proposal
     * @param vault Vault
     */
    function updateProposalUpvotes(Vault vault) external {
        require(isUpvoter(msg.sender), "Not an upvoter");

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

        _updateLeadingProposal(upvoter.proposalID);
    }
}
