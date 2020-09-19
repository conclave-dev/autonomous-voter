pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./celo/common/UsingRegistry.sol";
import "./celo/common/FixidityLib.sol";
import "./libraries/ElectionDataProvider.sol";
import "./Portfolio.sol";

contract Rewards is UsingRegistry {
    using SafeMath for uint256;
    using FixidityLib for FixidityLib.Fraction;
    using ElectionDataProvider for ElectionDataProvider;

    Portfolio public portfolio;

    function initialize(address registry_) public initializer {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
        getAccounts().createAccount();
    }

    modifier onlyPortfolio() {
        require(msg.sender == address(portfolio), "Caller is not Portfolio");
        _;
    }

    function setState(Portfolio portfolio_) external onlyOwner {
        portfolio = portfolio_;
    }

    function deposit() external payable {
        getLockedGold().lock.value(msg.value)();
    }

    /**
     * @notice Revokes votes for a group
     * @param amount Amount of votes to be revoked
     * @param group Group to revoke votes from
     */
    function _revoke(uint256 amount, address group) internal {
        IElection election = getElection();
        uint256 pendingVotes = election.getPendingVotesForGroupByAccount(
            group,
            address(this)
        );
        uint256 activeVotes = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );

        // Revoke pending votes first
        if (pendingVotes > 0) {
            uint256 pendingVotesToRevoke = amount <= pendingVotes
                ? amount
                : pendingVotes;
            (address lesserGroup, address greaterGroup) = ElectionDataProvider
                .findLesserAndGreaterGroups(
                election,
                group,
                pendingVotesToRevoke,
                true
            );

            election.revokePending(
                group,
                amount,
                lesserGroup,
                greaterGroup,
                ElectionDataProvider.findGroupIndexForAccount(
                    election,
                    group,
                    address(this)
                )
            );

            amount = amount.sub(pendingVotesToRevoke);
        }

        // Revoke active votes if pending votes did not cover the revoke amount
        if (amount > 0) {
            (address lesserGroup, address greaterGroup) = ElectionDataProvider
                .findLesserAndGreaterGroups(election, group, amount, true);

            election.revokeActive(
                group,
                amount,
                lesserGroup,
                greaterGroup,
                ElectionDataProvider.findGroupIndexForAccount(
                    election,
                    group,
                    address(this)
                )
            );

            activeVotes = activeVotes.sub(amount);
        }
    }

    function _vote(uint256 amount, address group) internal {
        (address lesserGroup, address greaterGroup) = ElectionDataProvider
            .findLesserAndGreaterGroups(getElection(), group, amount, false);

        getElection().vote(group, amount, lesserGroup, greaterGroup);
    }

    /**
     * @notice Lets the Portfolio revoke group votes according to its leading proposal
     */
    function tidyVotes() external onlyPortfolio {
        IElection election = getElection();
        address[] memory groups = election.getGroupsVotedForByAccount(
            address(this)
        );

        for (uint256 i = 0; i < groups.length; i += 1) {
            address group = groups[i];
            uint256 groupVotes = election.getTotalVotesForGroupByAccount(
                group,
                address(this)
            );
            uint256 portfolioGroupVotePercent = portfolio
                .getPortfolioGroupVotePercentByAddress(group);
            uint256 totalLockedGold = getLockedGold().getAccountTotalLockedGold(
                address(this)
            );
            uint256 portfolioGroupVotes = FixidityLib
                .newFixedFraction(totalLockedGold, 100)
                .multiply(FixidityLib.newFixed(portfolioGroupVotePercent))
                .fromFixed();

            // Revoke all votes for group if it is not within the leading proposal
            if (portfolioGroupVotes == 0) {
                _revoke(groupVotes, group);
                continue;
            }

            // Revoke excess votes for groups with more votes than proposed
            if (portfolioGroupVotes < groupVotes) {
                _revoke(groupVotes.sub(portfolioGroupVotes), group);
            }
        }
    }

    /**
     * @notice Lets the Portfolio place group votes according to its leading proposal
     */
    function applyVotes() external onlyPortfolio {
        IElection election = getElection();
        // Get leading proposal group addresses and vote percents from Portfolio
        (
            address[] memory groups,
            ,
            uint256[] memory groupVotePercents
        ) = portfolio.getPortfolioGroups();
        uint256 totalLockedGold = getLockedGold().getAccountTotalLockedGold(
            address(this)
        );

        for (uint256 i = 0; i < groups.length; i += 1) {
            address group = groups[i];
            uint256 portfolioGroupVotes = FixidityLib
                .newFixedFraction(totalLockedGold, 100)
                .multiply(FixidityLib.newFixed(groupVotePercents[i]))
                .fromFixed();
            // Calculate the difference between the portfolio group votes and the
            // current group votes. May encounter a subtraction overflow error if
            // `tidyVotes` was not called first
            uint256 votes = portfolioGroupVotes.sub(
                election.getTotalVotesForGroupByAccount(group, address(this))
            );

            // NOTE: It's possible for `votes` to be `0` if the group has received
            // all the votes that it should receive
            if (votes > 0) {
                _vote(votes, group);
            }
        }
    }
}
