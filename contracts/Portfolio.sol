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

    // The maximum number of unique groups that can receive votes
    uint256 public groupLimit;

    /**
     * @notice Initializes the Celo Registry contract and sets the owner
     * @param registry_ The address of the Celo Registry contract
     */
    function initialize(address registry_) public initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
        Ownable.initialize(msg.sender);
    }

    /**
     * @notice Sets the parameters for the genesis cycle and cycle block duration
     * @param genesis The first block for the genesis cycle
     * @param duration The number of blocks within a cycle
     */
    function setCycleParameters(uint256 genesis, uint256 duration)
        external
        onlyOwner
    {
        require(genesis >= block.number, "Genesis must be a future block");
        require(duration != 0, "Cycle block duration cannot be zero");

        genesisBlockNumber = genesis;
        blockDuration = duration;
    }

    /**
     * @notice Sets `groupLimit`
     * @param limit Max number of groups that can be voted for
     */
    function setGroupLimit(uint256 limit) external onlyOwner {
        require(limit > 0, "Group limit cannot be zero");
        groupLimit = limit;
    }

    /**
     * @notice Adds a vault whose votes will be managed
     * @param vault Vault contract instance
     */
    function addVault(Vault vault) external {
        require(msg.sender == vault.owner(), "Account is not vault owner");

        address vaultAddress = address(vault);

        require(vaults.contains(vaultAddress) == false, "Vault already exists");
        vaults.push(vaultAddress);
    }

    /**
     * @notice Validates a proposal prior to its submission
     * @param vault Vault contract instance
     * @param eligibleGroupIndexes Indexes of eligible Celo election groups
     * @param groupAllocations Percentage of total votes allocated to each group
     */
    function submitProposal(
        Vault vault,
        uint256[] memory eligibleGroupIndexes,
        uint256[] memory groupAllocations
    ) public {
        require(msg.sender == vault.owner(), "Account is not vault owner");

        require(
            eligibleGroupIndexes.length <= groupLimit,
            "Exceeds max groups allowed"
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
                "Eligible group does not exist"
            );

            // Track allocation total to validate amount is correct
            newAllocationTotal = newAllocationTotal.add(groupAllocations[i]);
        }

        // // Require newAllocationTotal fully allocates votes
        require(
            newAllocationTotal == 100,
            "Group allocation total must be 100"
        );

        _submit(vault, eligibleGroupIndexes, groupAllocations);
    }
}
