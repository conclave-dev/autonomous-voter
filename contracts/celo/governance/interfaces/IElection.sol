pragma solidity ^0.5.8;

interface IElection {
    function getTotalVotes() external view returns (uint256);

    function getActiveVotes() external view returns (uint256);

    function getTotalVotesByAccount(address) external view returns (uint256);

    function markGroupIneligible(address) external;

    function markGroupEligible(
        address,
        address,
        address
    ) external;

    function electValidatorSigners() external view returns (address[] memory);

    function vote(
        address,
        uint256,
        address,
        address
    ) external returns (bool);

    function activate(address) external returns (bool);

    function revokeActive(
        address,
        uint256,
        address,
        address,
        uint256
    ) external returns (bool);

    function revokePending(
        address,
        uint256,
        address,
        address,
        uint256
    ) external returns (bool);

    function forceDecrementVotes(
        address,
        uint256,
        address[] calldata,
        address[] calldata,
        uint256[] calldata
    ) external returns (uint256);

    // AV: Added fn interfaces
    function getActiveVotesForGroup(address group)
        external
        view
        returns (uint256);

    function getActiveVotesForGroupByAccount(address group, address account)
        external
        view
        returns (uint256);

    function revokeAllActive(
        address group,
        address lesser,
        address greater,
        uint256 index
    ) external returns (bool);

    function getPendingVotesForGroupByAccount(address group, address account)
        external
        view
        returns (uint256);

    function getTotalVotesForGroupByAccount(address group, address account)
        external
        view
        returns (uint256);

    function hasActivatablePendingVotes(address account, address group)
        external
        view
        returns (bool);

    function getTotalVotesForEligibleValidatorGroups()
        external
        view
        returns (address[] memory groups, uint256[] memory values);

    function getGroupsVotedForByAccount(address account)
        external
        view
        returns (address[] memory);

    function getEligibleValidatorGroups()
        external
        view
        returns (address[] memory);
}
