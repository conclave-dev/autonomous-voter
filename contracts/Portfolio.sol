pragma solidity ^0.5.8;

import "./celo/common/UsingRegistry.sol";
import "./celo/common/libraries/AddressLinkedList.sol";
import "./celo/governance/interfaces/IElection.sol";
import "./modules/Protocol.sol";
import "./modules/Proposals.sol";
import "./modules/ElectionManager.sol";
import "./Vault.sol";
import "./Bank.sol";

contract Portfolio is Protocol, Proposals, ElectionManager, UsingRegistry {
    using AddressLinkedList for LinkedList.List;

    // Factory contracts that are able to modify the lists below
    address public vaultFactory;

    // Vaults mapped by their owner's address
    mapping(address => LinkedList.List) public vaults;

    // The maximum number of unique Celo election groups will be voted for
    uint256 public electionGroupLimit;

    modifier onlyVaultFactory() {
        require(msg.sender == vaultFactory, "Sender is not the vault factory");
        _;
    }

    modifier onlyVault() {
        // Confirm that the calling Vault was created by the VaultFactory
        require(
            vaults[Vault(msg.sender).owner()].contains(msg.sender),
            "Invalid vault"
        );
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

    function setVaultFactory(address vaultFactory_) external onlyOwner {
        vaultFactory = vaultFactory_;
    }

    function getVaultsByOwner(address owner_)
        external
        view
        returns (address[] memory)
    {
        return vaults[owner_].getKeys();
    }

    function hasVault(address owner_, address vault)
        external
        view
        returns (bool)
    {
        return vaults[owner_].contains(vault);
    }

    function associateVaultWithOwner(address vault, address owner_)
        external
        onlyVaultFactory
    {
        require(!vaults[owner_].contains(vault), "Vault has already been set");
        vaults[owner_].push(vault);
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
    function setProposalsParameters(Bank bank_, uint256 proposerMinimum)
        external
        onlyOwner
    {
        require(
            proposerMinimum > 0,
            "Proposer balance minimum must be above zero"
        );

        bank = bank_;
        proposerBalanceMinimum = proposerMinimum;
    }

    function setElectionGroupLimit(uint256 limit) external onlyOwner {
        require(limit > 0, "Limit must be greater than zero");
        electionGroupLimit = limit;
    }

    /**
     * @notice Validates election group index and allocation parameters
     * @param groupIndexes Indexes referencing eligible Celo election groups
     * @param groupAllocations Percentage of total votes allocated to each group
     */
    function _validateElectionGroups(
        uint256[] memory groupIndexes,
        uint256[] memory groupAllocations
    ) internal view {
        require(
            groupIndexes.length <= electionGroupLimit,
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

    function _performStateMaintenance() internal {
        uint256 currentCycle = getCurrentCycle();

        // If the current cycle is more recent than the proposal cycle,
        // update election groups using the leading proposal and reset state
        if (currentProposalCycle < currentCycle) {
            Proposal memory leadingProposal = proposals[leadingProposalID];
            require(
                leadingProposal.groupIndexes.length > 0 &&
                    leadingProposal.groupAllocations.length > 0,
                "No new groups proposed"
            );

            setElectionGroups(
                leadingProposal.groupIndexes,
                leadingProposal.groupAllocations
            );

            // Reset proposal data
            delete proposals;
            delete leadingProposalID;

            currentProposalCycle = currentCycle;
        }
    }

    function isUpvoterInCurrentCycle(address account)
        external
        view
        returns (bool)
    {
        return _isUpvoterInCurrentCycle(account, getCurrentCycle());
    }

    function submitProposal(
        Vault vault,
        uint256[] calldata groupIndexes,
        uint256[] calldata groupAllocations
    ) external {
        _performStateMaintenance();
        _validateElectionGroups(groupIndexes, groupAllocations);
        _submitProposal(
            vault,
            groupIndexes,
            groupAllocations,
            getCurrentCycle()
        );
    }

    function addProposalUpvotes(Vault vault, uint256 proposalID) external {
        _performStateMaintenance();
        _addProposalUpvotes(vault, proposalID, getCurrentCycle());
    }

    function updateProposalUpvotes(Vault vault) external {
        _performStateMaintenance();
        _updateProposalUpvotes(vault, getCurrentCycle());
    }

    function setElectionGroups(
        uint256[] memory groupIndexes,
        uint256[] memory groupAllocations
    ) internal {
        _setGroups(groupIndexes, groupAllocations, getCurrentCycle());
    }
}
