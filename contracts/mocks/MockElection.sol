pragma solidity ^0.5.8;

import "./MockVault.sol";
import "./MockRegistry.sol";
import "../celo/common/libraries/AddressLinkedList.sol";

contract MockElection {
    using SafeMath for uint256;
    using AddressLinkedList for LinkedList.List;

    address public registry;
    address public lockedGold;

    mapping(address => mapping(address => uint256))
        public activeVotesForGroupsByAccounts;

    mapping(address => mapping(address => uint256))
        public pendingVotesForGroupsByAccounts;

    mapping(address => uint256) public groupTotalVotes;

    address[] public validatorGroups;

    function initValidatorGroups(address[] memory groups) public {
        validatorGroups.length = 0;

        for (uint256 i = 0; i < groups.length; i = i.add(1)) {
            validatorGroups.push(groups[i]);
            groupTotalVotes[groups[i]] = 0;
        }
    }

    function setRegistry(address _registry) public {
        registry = _registry;
        lockedGold = MockRegistry(registry).lockedGold();
    }

    function resetVotesForAccount(address payable account) public {
        address[] memory groups = MockVault(account).getVotedGroups();

        for (uint256 i = 0; i < groups.length; i = i.add(1)) {
            activeVotesForGroupsByAccounts[account][groups[i]] = 0;
            pendingVotesForGroupsByAccounts[account][groups[i]] = 0;
        }
    }

    function distributeRewardForGroupByAccount(
        address group,
        address account,
        uint256 reward
    ) public {
        activeVotesForGroupsByAccounts[account][group] = activeVotesForGroupsByAccounts[account][group]
            .add(reward);
        groupTotalVotes[group] = groupTotalVotes[group].add(reward);
    }

    function getActiveVotesForGroupByAccount(address group, address account)
        public
        view
        returns (uint256)
    {
        return activeVotesForGroupsByAccounts[account][group];
    }

    function getPendingVotesForGroupByAccount(address group, address account)
        public
        view
        returns (uint256)
    {
        return pendingVotesForGroupsByAccounts[account][group];
    }

    function getTotalVotesForGroupByAccount(address group, address account)
        public
        view
        returns (uint256)
    {
        return
            activeVotesForGroupsByAccounts[account][group].add(
                pendingVotesForGroupsByAccounts[account][group]
            );
    }

    function voteForGroupByAccount(
        address group,
        address account,
        uint256 amount
    ) public {
        pendingVotesForGroupsByAccounts[account][group] = pendingVotesForGroupsByAccounts[account][group]
            .add(amount);
        groupTotalVotes[group] = groupTotalVotes[group].add(amount);
        ILockedGold(lockedGold).decrementNonvotingAccountBalance(
            account,
            amount
        );
    }

    function activateForGroupByAccount(address group, address account) public {
        activeVotesForGroupsByAccounts[account][group] = activeVotesForGroupsByAccounts[account][group]
            .add(pendingVotesForGroupsByAccounts[account][group]);
        pendingVotesForGroupsByAccounts[account][group] = 0;
    }

    function revokeActive(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) public returns (bool) {
        activeVotesForGroupsByAccounts[msg
            .sender][group] = activeVotesForGroupsByAccounts[msg.sender][group]
            .sub(amount);
        groupTotalVotes[group] = groupTotalVotes[group].sub(amount);
        ILockedGold(lockedGold).incrementNonvotingAccountBalance(
            msg.sender,
            amount
        );
        return true;
    }

    function revokePending(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) public returns (bool) {
        pendingVotesForGroupsByAccounts[msg
            .sender][group] = pendingVotesForGroupsByAccounts[msg.sender][group]
            .sub(amount);
        groupTotalVotes[group] = groupTotalVotes[group].sub(amount);
        ILockedGold(lockedGold).incrementNonvotingAccountBalance(
            msg.sender,
            amount
        );
        return true;
    }

    function getTotalVotesForEligibleValidatorGroups()
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        address[] memory groups = new address[](validatorGroups.length);
        uint256[] memory votes = new uint256[](validatorGroups.length);
        for (uint256 i = 0; i < validatorGroups.length; i = i.add(1)) {
            groups[i] = validatorGroups[i];
            votes[i] = groupTotalVotes[validatorGroups[i]];
        }

        return (groups, votes);
    }
}
