// contracts/Voting.sol
pragma solidity ^0.5.8;

import "./modules/MCycle.sol";
import "./modules/MProposals.sol";
import "./modules/MVotes.sol";
import "./celo/common/UsingRegistry.sol";
import "./celo/common/libraries/AddressLinkedList.sol";
import "./Vault.sol";

contract Portfolio is MCycle, MProposals, MVotes, UsingRegistry {
    using AddressLinkedList for LinkedList.List;

    LinkedList.List public vaults;

    // Maximum number of groups within a vote allocation
    uint256 public maximumVoteAllocationGroups;

    function initialize(address registry_) public initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
        Ownable.initialize(msg.sender);
    }

    function setCycleParameters(uint256 genesis, uint256 duration)
        external
        onlyOwner
    {
        _setCycleParameters(genesis, duration);
    }

    /**
     * @notice Sets the max number of groups that can be allocated votes
     * @param max Maximum number of groups within a vote allocation
     */
    function setMaximumVoteAllocationGroups(uint256 max) external onlyOwner {
        maximumVoteAllocationGroups = max;
    }

    function addVault(Vault vault) external {
        require(msg.sender == vault.owner(), "Sender is not vault owner");
        vaults.push(address(vault));
    }

    function _validateVoteAllocationProposal(
        uint256[] memory eligibleGroupIndexes,
        uint256[] memory groupAllocations
    ) internal view {
        require(
            eligibleGroupIndexes.length <= maximumVoteAllocationGroups,
            "Exceeds max groups allowed"
        );
        require(
            eligibleGroupIndexes.length == groupAllocations.length,
            "Mismatched indexes and groupAllocations"
        );

        // Fetch eligible Celo election groups for validation purposes
        (address[] memory groups, ) = getElection()
            .getTotalVotesForEligibleValidatorGroups();

        uint256 newAllocationTotal;

        for (uint256 i = 0; i < eligibleGroupIndexes.length; i += 1) {
            // TODO: Check whether group index has already been added?
            // If the group index is greater than the length of eligible Celo groups
            // Then it is out of range
            require(
                eligibleGroupIndexes[i] < groups.length,
                "Eligible group does not exist at index"
            );

            // Track allocation total to validate amount is correct
            newAllocationTotal = newAllocationTotal.add(groupAllocations[i]);
        }

        // // Require newAllocationTotal fully allocates votes
        require(newAllocationTotal == 100, "Group allocations must be 100");
    }

    /**
     * @notice Submits a vote allocation proposal
     * @param eligibleGroupIndexes List of eligible Celo election group indexes
     * @param groupAllocations Percentage of total votes allocated for the groups
     * @dev The allocation for a group is based on its index in eligibleGroupIndexes
     * @dev E.g. The allocation for `eligibleGroupIndexes[0]` is `groupAllocations[0]`
     */
    function submitVoteAllocationProposal(
        uint256[] memory eligibleGroupIndexes,
        uint256[] memory groupAllocations
    ) public {
        _validateVoteAllocationProposal(eligibleGroupIndexes, groupAllocations);
        _submit(eligibleGroupIndexes, groupAllocations);
    }
}
