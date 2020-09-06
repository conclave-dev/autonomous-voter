pragma solidity ^0.5.8;

import "./celo/common/UsingRegistry.sol";
import "./celo/governance/interfaces/IElection.sol";
import "./modules/Protocol.sol";
import "./modules/ElectionManager.sol";
import "./Vault.sol";
import "./Bank.sol";

contract Portfolio is Protocol, ElectionManager, UsingRegistry {
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
    }

    Bank public bank;
    Proposal[] public proposals;
    mapping(address => Upvoter) public upvoters;
    // Maximum number of groups that can be proposed
    uint256 public proposalGroupLimit;
    // Minimum vault balance required to submit a proposal
    uint256 public proposerBalanceMinimum;
    uint256 public leadingProposalID;

    // Factory contracts that are able to modify the lists below
    address public vaultFactory;

    // A Celo account mapped to its vault contract
    mapping(address => address) public vaults;

    modifier onlyVaultFactory() {
        require(msg.sender == vaultFactory, "Sender is not the vault factory");
        _;
    }

    /**
     * @notice Initializes the Celo Registry contract and sets the owner
     * @param registry_ The address of the Celo Registry contract
     */
    function initialize(address registry_) public initializer {
        Ownable.initialize(msg.sender);
        UsingRegistry.initializeRegistry(msg.sender, registry_);
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
            groupIndexes.length <= proposalGroupLimit,
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
     * @dev The allocation for a group is based on its index in groupIndexes
     */
    function submitProposal(
        Vault vault,
        uint256[] calldata groupIndexes,
        uint256[] calldata groupAllocations
    ) external {
        uint256 upvotes = getUpvotesForVaultOwner(vault);
        require(upvotes >= proposerBalanceMinimum, "Insufficient upvotes");
        require(isUpvoter(msg.sender) == false, "Already an upvoter");

        address[] memory proposalUpvoters;
        uint256 proposalID = proposals.length;
        proposals.push(
            Proposal(proposalUpvoters, upvotes, groupIndexes, groupAllocations)
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

    function setVaultFactory(address vaultFactory_) external onlyOwner {
        vaultFactory = vaultFactory_;
    }

    function getVaultByOwner(address owner_) public view returns (address) {
        return vaults[owner_];
    }

    function setVault(address owner_, address vault) external onlyVaultFactory {
        require(
            getVaultByOwner(owner_) == address(0),
            "Vault has already been set"
        );
        vaults[owner_] = vault;
    }

    // Sets the parameters for the Protocol module
    function setProtocolParameters(uint256 genesis, uint256 duration)
        external
        onlyOwner
    {
        require(genesis > 0, "Genesis block number must be greater than zero");
        require(duration > 0, "Cycle block duration must be greater than zero");

        genesisBlockNumber = genesis;
        blockDuration = duration;
    }

    // Sets the parameters for the Proposals module
    function setProposalsParameters(
        Bank bank_,
        uint256 proposalGroupLimit_,
        uint256 proposerBalanceMinimum_
    ) external onlyOwner {
        require(
            proposalGroupLimit_ > 0,
            "Proposal group limit must be greater than zero"
        );
        require(
            proposerBalanceMinimum_ > 0,
            "Proposer balance minimum must be greater than zero"
        );

        bank = bank_;
        proposalGroupLimit = proposalGroupLimit_;
        proposerBalanceMinimum = proposerBalanceMinimum_;
    }
}
