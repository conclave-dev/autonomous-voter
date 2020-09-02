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
}
