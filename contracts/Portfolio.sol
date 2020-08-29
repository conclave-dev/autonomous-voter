// contracts/Voting.sol
pragma solidity ^0.5.8;

import "./modules/MCycle.sol";
import "./modules/MProposals.sol";
import "./modules/MVotes.sol";
import "./celo/common/UsingRegistry.sol";
import "./celo/common/libraries/AddressLinkedList.sol";
import "./celo/governance/interfaces/IElection.sol";
import "./Vault.sol";
import "./Bank.sol";

contract Portfolio is MCycle, MProposals, MVotes, UsingRegistry {
    using AddressLinkedList for LinkedList.List;

    LinkedList.List public vaults;

    /**
     * @notice Initializes the Celo Registry contract and sets the owner
     * @param registry_ The address of the Celo Registry contract
     */
    function initialize(address registry_) public initializer {
        Ownable.initialize(msg.sender);
        UsingRegistry.initializeRegistry(msg.sender, registry_);
    }

    // Sets the parameters for the Cycle module
    function setCycleParameters(uint256 genesis, uint256 duration)
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
        uint256 groupLimit,
        uint256 proposerMinimum
    ) external onlyOwner {
        require(groupLimit > 0, "Group limit must be above zero");
        require(
            proposerMinimum > 0,
            "Proposer balance minimum must be above zero"
        );

        bank = bank_;
        election = getElection();
        proposalGroupLimit = groupLimit;
        proposerBalanceMinimum = proposerMinimum;
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
}
