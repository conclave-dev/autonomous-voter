pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./celo/common/UsingRegistry.sol";
import "./celo/common/libraries/UsingPrecompiles.sol";
import "./celo/common/libraries/AddressLinkedList.sol";
import "./celo/common/libraries/IntegerSortedLinkedList.sol";
import "./interfaces/IBank.sol";
import "./interfaces/IRewards.sol";
import "./interfaces/IVault.sol";

contract Portfolio is UsingRegistry, UsingPrecompiles {
    using SafeMath for uint256;
    using AddressLinkedList for LinkedList.List;
    using IntegerSortedLinkedList for SortedLinkedList.List;

    struct Proposal {
        // The account that submitted the proposal
        address proposer;
        // The accounts that have upvoted the proposal
        LinkedList.List upvoters;
        // The cumulative vault balances of the proposal
        uint256 upvotes;
        // Indexes which reference eligible Celo groups
        uint256[] groupIndexes;
        mapping(uint256 => uint256) groupVotePercentByIndex;
    }

    // Accounts that have upvoted a proposal
    struct Upvoter {
        uint256 upvotes;
        uint256 proposalID;
    }

    // Frequently-accessed Celo election data
    struct PortfolioGroups {
        uint256 epochUpdated;
        mapping(address => uint256) indexesByAddress;
        mapping(uint256 => address) addressesByIndex;
        mapping(address => uint256) votePercentsByAddress;
    }

    IBank bank;
    // Enables the Portfolio to only add vaults created by a known factory
    address vaultFactory;
    // Minimum balance required to submit or upvote a proposal
    uint256 public minimumUpvoterBalance;
    // Maximum number of groups that can be proposed
    uint256 public maximumProposalGroups;

    mapping(address => address) public vaultsByOwner;
    mapping(uint256 => Proposal) proposals;
    mapping(address => Upvoter) public upvoters;
    SortedLinkedList.List proposalUpvotesByID;
    PortfolioGroups portfolioGroups;

    /**
     * @notice Initializes Portfolio contract
     * @param registry_ Celo Registry contract
     */
    function initialize(address registry_) public initializer {
        Ownable.initialize(msg.sender);
        UsingRegistry.initializeRegistry(msg.sender, registry_);
    }

    function setContracts(IBank bank_, address vaultFactory_)
        external
        onlyOwner
    {
        bank = bank_;
        vaultFactory = vaultFactory_;
    }

    function setParameters(
        uint256 minimumUpvoterBalance_,
        uint256 maximumProposalGroups_
    ) external onlyOwner {
        minimumUpvoterBalance = minimumUpvoterBalance_;
        maximumProposalGroups = maximumProposalGroups_;
    }

    // Sets the vault
    function setVaultByOwner(address owner_, address vault) external {
        require(
            msg.sender == vaultFactory,
            "Caller is not the VaultFactory contract"
        );
        vaultsByOwner[owner_] = vault;
    }

    /**
     * @notice Validates election group index and allocation parameters
     * @param groupIndexes Indexes referencing eligible Celo election groups
     * @param groupVotePercents Percentage of total votes allocated to each group
     */
    function _validateProposal(
        uint256[] memory groupIndexes,
        uint256[] memory groupVotePercents
    ) internal view {
        require(
            groupIndexes.length <= maximumProposalGroups &&
                groupIndexes.length == groupVotePercents.length,
            "Invalid number of group index or vote percent elements"
        );

        // Fetch eligible Celo election groups to ensure group indexes are valid
        (address[] memory celoGroupIndexes, ) = getElection()
            .getTotalVotesForEligibleValidatorGroups();

        // For validating that the group allocation total is 100
        uint256 groupAllocationTotal;

        for (uint256 i = 0; i < groupIndexes.length; i += 1) {
            require(
                groupIndexes[i] < celoGroupIndexes.length,
                "Index must be that of an eligible Celo group"
            );

            groupAllocationTotal = groupAllocationTotal.add(
                groupVotePercents[i]
            );
        }

        require(
            groupAllocationTotal == 100,
            "Total group allocation must be 100"
        );
    }

    /**
     * @notice Gets the upvotes of a vault owner
     * @param vault Vault
     */
    function verifyVaultOwnershipAndGetUpvotes(IVault vault)
        private
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
            uint256 upvotes,
            uint256[] memory groupIndexes,
            uint256[] memory groupVotePercents
        )
    {
        Proposal storage proposal = proposals[proposalID];
        groupVotePercents = new uint256[](proposal.groupIndexes.length);

        for (uint256 i = 0; i < proposal.groupIndexes.length; i += 1) {
            uint256 groupIndex = proposal.groupIndexes[i];
            groupVotePercents[i] = proposal.groupVotePercentByIndex[groupIndex];
        }

        return (proposal.upvotes, proposal.groupIndexes, groupVotePercents);
    }

    /**
     * @notice Submits a proposal
     * @param vault Vault
     * @param groupIndexes List of eligible Celo election group indexes
     * @param groupVotePercents Percentage of total votes allocated for the groups
     * @param lesserProposalID Proposal with lesser upvotes after upvotes are set
     * @param greaterProposalID Proposal with greater upvotes after upvotes are set
     * @dev Group indexes and allocations have the same indexes for their arrays
     * @dev Set lesser or greater proposal ID to zero if they do not exist
     */
    function addProposal(
        IVault vault,
        uint256[] calldata groupIndexes,
        uint256[] calldata groupVotePercents,
        uint256 lesserProposalID,
        uint256 greaterProposalID
    ) external {
        _validateProposal(groupIndexes, groupVotePercents);

        address proposer = msg.sender;
        require(upvoters[proposer].upvotes == 0, "Already an upvoter");

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
            groupIndexes
        );
        Proposal storage proposal = proposals[newProposalID];
        proposal.upvoters.push(proposer);
        upvoters[proposer] = Upvoter(newProposalUpvotes, newProposalID);

        for (uint256 i = 0; i < groupIndexes.length; i += 1) {
            uint256 groupIndex = groupIndexes[i];
            // Increment group indexes by 1, since the sorted list does accept 0 as a key
            proposal.groupVotePercentByIndex[groupIndex] = groupVotePercents[i];
        }
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
        IVault vault,
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

    function updatePortfolioGroups() public {
        uint256 epoch = getEpochNumber();

        if (portfolioGroups.epochUpdated == epoch) {
            return;
        }

        delete portfolioGroups;
        portfolioGroups.epochUpdated = epoch;

        (uint256[] memory proposalIDs, ) = proposalUpvotesByID.getElements();
        Proposal storage leadingProposal = proposals[proposalIDs[0]];
        address[] memory eligibleValidatorGroups = getElection()
            .getEligibleValidatorGroups();

        require(
            leadingProposal.groupIndexes.length <=
                eligibleValidatorGroups.length,
            "Invalid proposal groups set"
        );

        for (uint256 i = 0; i < leadingProposal.groupIndexes.length; i += 1) {
            uint256 groupIndex = leadingProposal.groupIndexes[i];
            address groupAddress = eligibleValidatorGroups[groupIndex];

            portfolioGroups.indexesByAddress[groupAddress] = groupIndex;
            portfolioGroups.addressesByIndex[groupIndex] = groupAddress;
            portfolioGroups
                .votePercentsByAddress[groupAddress] = leadingProposal
                .groupVotePercentByIndex[groupIndex];
        }

        // emit PortfolioGroupsUpdated(epoch);
    }

    function getPortfolioGroupVotePercentByAddress(address group)
        public
        view
        returns (uint256 votePercent)
    {
        return portfolioGroups.votePercentsByAddress[group];
    }

    function getPortfolioGroups()
        public
        view
        returns (
            address[] memory groups,
            uint256[] memory groupIndexes,
            uint256[] memory groupVotePercents
        )
    {
        require(
            portfolioGroups.epochUpdated == getEpochNumber(),
            "Portfolio groups need to be updated"
        );

        (uint256[] memory proposalIDs, ) = proposalUpvotesByID.getElements();
        Proposal storage leadingProposal = proposals[proposalIDs[0]];
        groups = new address[](leadingProposal.groupIndexes.length);
        groupVotePercents = new uint256[](leadingProposal.groupIndexes.length);

        for (uint256 i = 0; i < leadingProposal.groupIndexes.length; i += 1) {
            uint256 groupIndex = leadingProposal.groupIndexes[i];
            groups[i] = portfolioGroups.addressesByIndex[groupIndex];
            groupVotePercents[i] = leadingProposal
                .groupVotePercentByIndex[groupIndex];
        }

        return (groups, leadingProposal.groupIndexes, groupVotePercents);
    }

    /**
     * @notice Calls the voter contract's `tidyVotes` method
     * @param rewards Rewards contract instance
     */
    function tidyVotes(IRewards rewards) public {
        updatePortfolioGroups();
        rewards.tidyVotes();
    }

    /**
     * @notice Calls the voter contract's `applyVotes` method
     * @param rewards Rewards contract instance
     */
    function applyVotes(IRewards rewards) public {
        updatePortfolioGroups();
        rewards.applyVotes();
    }
}
