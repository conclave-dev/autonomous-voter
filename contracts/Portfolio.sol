// contracts/Voting.sol
pragma solidity ^0.5.8;

import "./modules/MVoting.sol";
import "./celo/common/UsingRegistry.sol";
import "./celo/common/libraries/AddressLinkedList.sol";
import "./Vault.sol";

contract Portfolio is MVoting, UsingRegistry {
    using AddressLinkedList for LinkedList.List;

    LinkedList.List public vaults;

    function initialize(address registry_, uint256 max)
        public
        payable
        initializer
    {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
        Ownable.initialize(msg.sender);

        // Set Voting module parameters
        _setGroupMaximum(max);
    }

    function addVault(Vault vault) external {
        require(msg.sender == vault.owner(), "Sender is not vault owner");
        vaults.push(address(vault));
    }

    /**
     * @notice Validates and sets vote allocations for multiple groups
     * @param eligibleGroupIndexes List of eligible Celo election group indexes
     * @param groupAllocations Percentage of total votes allocated for the groups
     * @dev The allocation for a group is based on its index in eligibleGroupIndexes
     * @dev E.g. The allocation for `eligibleGroupIndexes[0]` is `groupAllocations[0]`
     */
    function setVoteAllocations(
        uint256[] calldata eligibleGroupIndexes,
        uint256[] calldata groupAllocations
    ) external onlyOwner {
        require(
            eligibleGroupIndexes.length <= groupMaximum,
            "Exceeds max groups allowed"
        );
        require(
            eligibleGroupIndexes.length == groupAllocations.length,
            "Mismatched indexes and groupAllocations"
        );

        // Fetch eligible Celo election groups for validation purposes
        (address[] memory groups, ) = getElection()
            .getTotalVotesForEligibleValidatorGroups();

        // Reset `voteAllocations` to an empty array
        delete voteAllocations;

        uint256 newAllocationTotal;

        for (uint256 i = 0; i < eligibleGroupIndexes.length; i += 1) {
            // TODO: Check whether group index has already been added?
            // If the group index is greater than the length of eligible Celo groups
            // Then it is out of range
            require(
                eligibleGroupIndexes[i] < groups.length,
                "Eligible group does not exist at index"
            );

            // Add group vote allocation
            voteAllocations.push(
                Group(eligibleGroupIndexes[i], groupAllocations[i], 0)
            );

            // Track allocation total to validate amount is correct
            newAllocationTotal = newAllocationTotal.add(groupAllocations[i]);
        }

        // // Require newAllocationTotal fully allocates votes
        require(newAllocationTotal == 100, "Group allocations must be 100");
    }
}
