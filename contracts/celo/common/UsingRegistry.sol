pragma solidity ^0.5.3;

// Swapped these openzeppelin contracts to their initializable counterparts
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

import "celo-monorepo/packages/protocol/contracts/common/interfaces/IAccounts.sol";
import "celo-monorepo/packages/protocol/contracts/common/interfaces/IFeeCurrencyWhitelist.sol";
import "celo-monorepo/packages/protocol/contracts/common/interfaces/IFreezer.sol";
import "celo-monorepo/packages/protocol/contracts/common/interfaces/IRegistry.sol";

import "celo-monorepo/packages/protocol/contracts/governance/interfaces/IGovernance.sol";

import "celo-monorepo/packages/protocol/contracts/identity/interfaces/IRandom.sol";
import "celo-monorepo/packages/protocol/contracts/identity/interfaces/IAttestations.sol";

import "celo-monorepo/packages/protocol/contracts/stability/interfaces/IExchange.sol";
import "celo-monorepo/packages/protocol/contracts/stability/interfaces/IReserve.sol";
import "celo-monorepo/packages/protocol/contracts/stability/interfaces/ISortedOracles.sol";
import "celo-monorepo/packages/protocol/contracts/stability/interfaces/IStableToken.sol";

// AV: Use local, modified versions of Celo protocol contract interfaces
import "../governance/interfaces/IElection.sol";
import "../governance/interfaces/IValidators.sol";
import "../governance/interfaces/IEpochRewards.sol";
import "../governance/interfaces/ILockedGold.sol";

contract UsingRegistry is Ownable {
    event RegistrySet(address indexed registryAddress);

    // solhint-disable state-visibility
    bytes32 constant ACCOUNTS_REGISTRY_ID = keccak256(
        abi.encodePacked("Accounts")
    );
    bytes32 constant ATTESTATIONS_REGISTRY_ID = keccak256(
        abi.encodePacked("Attestations")
    );
    bytes32 constant DOWNTIME_SLASHER_REGISTRY_ID = keccak256(
        abi.encodePacked("DowntimeSlasher")
    );
    bytes32 constant DOUBLE_SIGNING_SLASHER_REGISTRY_ID = keccak256(
        abi.encodePacked("DoubleSigningSlasher")
    );
    bytes32 constant ELECTION_REGISTRY_ID = keccak256(
        abi.encodePacked("Election")
    );
    bytes32 constant EXCHANGE_REGISTRY_ID = keccak256(
        abi.encodePacked("Exchange")
    );
    bytes32 constant FEE_CURRENCY_WHITELIST_REGISTRY_ID = keccak256(
        abi.encodePacked("FeeCurrencyWhitelist")
    );
    bytes32 constant FREEZER_REGISTRY_ID = keccak256(
        abi.encodePacked("Freezer")
    );
    bytes32 constant GOLD_TOKEN_REGISTRY_ID = keccak256(
        abi.encodePacked("GoldToken")
    );
    bytes32 constant GOVERNANCE_REGISTRY_ID = keccak256(
        abi.encodePacked("Governance")
    );
    bytes32 constant GOVERNANCE_SLASHER_REGISTRY_ID = keccak256(
        abi.encodePacked("GovernanceSlasher")
    );
    bytes32 constant LOCKED_GOLD_REGISTRY_ID = keccak256(
        abi.encodePacked("LockedGold")
    );
    bytes32 constant RESERVE_REGISTRY_ID = keccak256(
        abi.encodePacked("Reserve")
    );
    bytes32 constant RANDOM_REGISTRY_ID = keccak256(abi.encodePacked("Random"));
    bytes32 constant SORTED_ORACLES_REGISTRY_ID = keccak256(
        abi.encodePacked("SortedOracles")
    );
    bytes32 constant STABLE_TOKEN_REGISTRY_ID = keccak256(
        abi.encodePacked("StableToken")
    );
    bytes32 constant VALIDATORS_REGISTRY_ID = keccak256(
        abi.encodePacked("Validators")
    );

    // AV: Set EpochRewards registry ID constant
    bytes32 constant EPOCH_REWARDS_REGISTRY_ID = keccak256(
        abi.encodePacked("EpochRewards")
    );

    // solhint-enable state-visibility

    IRegistry public registry;

    // The base initialize() method for UsingRegistry to comply with Initializable
    function initializeRegistry(address owner_, address registryAddress)
        public
        initializer
    {
        Ownable.initialize(owner_);
        setRegistry(registryAddress);
    }

    /**
     * @notice Updates the address pointing to a Registry contract.
     * @param registryAddress The address of a registry contract for routing to other contracts.
     */
    function setRegistry(address registryAddress) public onlyOwner {
        require(
            registryAddress != address(0),
            "Cannot register the null address"
        );
        registry = IRegistry(registryAddress);
        emit RegistrySet(registryAddress);
    }

    function getAccounts() internal view returns (IAccounts) {
        return IAccounts(registry.getAddressForOrDie(ACCOUNTS_REGISTRY_ID));
    }

    function getAttestations() internal view returns (IAttestations) {
        return
            IAttestations(
                registry.getAddressForOrDie(ATTESTATIONS_REGISTRY_ID)
            );
    }

    function getElection() internal view returns (IElection) {
        return IElection(registry.getAddressForOrDie(ELECTION_REGISTRY_ID));
    }

    function getExchange() internal view returns (IExchange) {
        return IExchange(registry.getAddressForOrDie(EXCHANGE_REGISTRY_ID));
    }

    function getFeeCurrencyWhitelistRegistry()
        internal
        view
        returns (IFeeCurrencyWhitelist)
    {
        return
            IFeeCurrencyWhitelist(
                registry.getAddressForOrDie(FEE_CURRENCY_WHITELIST_REGISTRY_ID)
            );
    }

    function getFreezer() internal view returns (IFreezer) {
        return IFreezer(registry.getAddressForOrDie(FREEZER_REGISTRY_ID));
    }

    function getGoldToken() internal view returns (IERC20) {
        return IERC20(registry.getAddressForOrDie(GOLD_TOKEN_REGISTRY_ID));
    }

    function getGovernance() internal view returns (IGovernance) {
        return IGovernance(registry.getAddressForOrDie(GOVERNANCE_REGISTRY_ID));
    }

    function getLockedGold() internal view returns (ILockedGold) {
        return
            ILockedGold(registry.getAddressForOrDie(LOCKED_GOLD_REGISTRY_ID));
    }

    function getRandom() internal view returns (IRandom) {
        return IRandom(registry.getAddressForOrDie(RANDOM_REGISTRY_ID));
    }

    function getReserve() internal view returns (IReserve) {
        return IReserve(registry.getAddressForOrDie(RESERVE_REGISTRY_ID));
    }

    function getSortedOracles() internal view returns (ISortedOracles) {
        return
            ISortedOracles(
                registry.getAddressForOrDie(SORTED_ORACLES_REGISTRY_ID)
            );
    }

    function getStableToken() internal view returns (IStableToken) {
        return
            IStableToken(registry.getAddressForOrDie(STABLE_TOKEN_REGISTRY_ID));
    }

    function getValidators() internal view returns (IValidators) {
        return IValidators(registry.getAddressForOrDie(VALIDATORS_REGISTRY_ID));
    }

    function getEpochRewards() internal view returns (IEpochRewards) {
        return
            IEpochRewards(
                registry.getAddressForOrDie(EPOCH_REWARDS_REGISTRY_ID)
            );
    }
}
