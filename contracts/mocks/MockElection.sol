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

    function revokeActive(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) public returns (bool) {
        uint256 activeVotes = getActiveVotesForGroupByAccount(
            group,
            msg.sender
        );
        setActiveVotesForGroupByAccount(
            group,
            msg.sender,
            activeVotes - amount
        );
        return true;
    }
}
