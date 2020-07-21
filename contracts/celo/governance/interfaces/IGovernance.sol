// contracts/celo/governance/interfaces/IGovernance.sol
pragma solidity ^0.5.8;

interface IGovernance {
    function propose(
        uint256[] calldata values,
        address[] calldata destinations,
        bytes calldata data,
        uint256[] calldata dataLengths,
        string calldata descriptionUrl
    ) external payable returns (uint256);

    function upvote(
        uint256 proposalId,
        uint256 lesser,
        uint256 greater
    ) external returns (bool);

    function revokeUpvote(uint256 lesser, uint256 greater)
        external
        returns (bool);

    function approve(uint256 proposalId, uint256 index) external returns (bool);

    function vote(
        uint256 proposalId,
        uint256 index,
        uint8 value
    ) external returns (bool);

    function execute(uint256 proposalId, uint256 index) external returns (bool);

    function approveHotfix(bytes32 hash) external;

    function whitelistHotfix(bytes32 hash) external;

    function executeHotfix(
        uint256[] calldata values,
        address[] calldata destinations,
        bytes calldata data,
        uint256[] calldata dataLengths,
        bytes32 salt
    ) external;

    function withdraw() external returns (bool);

    function prepareHotfix(bytes32 hash) external;

    function dequeueProposalsIfReady() external;
}
