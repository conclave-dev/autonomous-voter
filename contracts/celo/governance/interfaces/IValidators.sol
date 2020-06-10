pragma solidity ^0.5.3;

import "celo-monorepo/packages/protocol/contracts/common/FixidityLib.sol";


interface IValidators {
    struct MembershipHistoryEntry {
        uint256 epochNumber;
        address group;
    }

    struct MembershipHistory {
        // The key to the most recent entry in the entries mapping.
        uint256 tail;
        // The number of entries in this validators membership history.
        uint256 numEntries;
        mapping(uint256 => MembershipHistoryEntry) entries;
        uint256 lastRemovedFromGroupTimestamp;
    }

    struct PublicKeys {
        bytes ecdsa;
        bytes bls;
    }

    struct Validator {
        PublicKeys publicKeys;
        address affiliation;
        FixidityLib.Fraction score;
        MembershipHistory membershipHistory;
    }

    function getAccountLockedGoldRequirement(address)
        external
        view
        returns (uint256);

    function meetsAccountLockedGoldRequirements(address)
        external
        view
        returns (bool);

    function getGroupNumMembers(address) external view returns (uint256);

    function getGroupsNumMembers(address[] calldata)
        external
        view
        returns (uint256[] memory);

    function getNumRegisteredValidators() external view returns (uint256);

    function getTopGroupValidators(address, uint256)
        external
        view
        returns (address[] memory);

    function updateEcdsaPublicKey(
        address,
        address,
        bytes calldata
    ) external returns (bool);

    function updatePublicKeys(
        address,
        address,
        bytes calldata,
        bytes calldata,
        bytes calldata
    ) external returns (bool);

    function isValidator(address) external view returns (bool);

    function isValidatorGroup(address) external view returns (bool);

    function calculateGroupEpochScore(uint256[] calldata uptimes)
        external
        view
        returns (uint256);

    function groupMembershipInEpoch(
        address account,
        uint256 epochNumber,
        uint256 index
    ) external view returns (address);

    function halveSlashingMultiplier(address group) external;

    function forceDeaffiliateIfValidator(address validator) external;

    function getValidatorGroupSlashingMultiplier(address)
        external
        view
        returns (uint256);

    function affiliate(address group) external returns (bool);

    // AV: Added fn interfaces
    function getValidatorGroup(address account)
        external
        view
        returns (
            address[] memory,
            uint256,
            uint256,
            uint256,
            uint256[] memory,
            uint256,
            uint256
        );

    function getValidator(address account)
        external
        view
        returns (
            bytes memory ecdsaPublicKey,
            bytes memory blsPublicKey,
            address affiliation,
            uint256 score,
            address signer
        );
}
