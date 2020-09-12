pragma solidity ^0.5.8;

interface IElectionDataProvider {
    function findLesserAndGreaterGroups(
        address group,
        uint256 votes,
        bool isRevoke
    ) external view returns (address, address);

    function findGroupIndexForAccount(address group, address account)
        external
        view
        returns (uint256);

    function updateElectionGroups() external;

    function getElectionGroupIndex(address) external view returns (uint256);
}
