pragma solidity ^0.5.8;

contract MockElection {
    mapping(address => mapping(address => uint256))
        public activeVotesForGroupsByAccounts;

    function setActiveVotesForGroupByAccount(
        address group,
        address account,
        uint256 activeVotes
    ) public {
        activeVotesForGroupsByAccounts[account][group] = activeVotes;
    }

    function getActiveVotesForGroupByAccount(address group, address account)
        public
        view
        returns (uint256)
    {
        return activeVotesForGroupsByAccounts[account][group];
    }
}
