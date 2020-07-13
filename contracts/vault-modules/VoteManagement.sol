// contracts/Vault.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../Archive.sol";
import "../Manager.sol";
import "../celo/governance/interfaces/IElection.sol";
import "../celo/common/FixidityLib.sol";
import "../celo/common/libraries/LinkedList.sol";

contract VoteManagement is Ownable {
    using SafeMath for uint256;
    using FixidityLib for FixidityLib.Fraction;
    using LinkedList for LinkedList.List;

    Archive public archive;
    IElection public election;

    address public manager;
    uint256 public managerCommission;
    uint256 public managerMinimumBalanceRequirement;
    uint256 public managerRewards;
    mapping(address => uint256) public activeVotes;

    function initialize(address archive_, IElection election_)
        public
        initializer
    {
        archive = Archive(archive_);
        election = election_;
    }

    modifier onlyVoteManager() {
        require(msg.sender == manager, "Not the vote manager");
        _;
    }

    function getVoteManager() external view returns (address, uint256) {
        return (manager, managerCommission);
    }

    function setVoteManager(Manager manager_) external onlyOwner {
        require(
            archive.hasManager(manager_.owner(), address(manager_)),
            "Vote manager is invalid"
        );
        require(manager == address(0), "Vote manager already exists");

        manager = address(manager_);
        archive.associateVaultWithManager(manager);

        managerCommission = manager_.commission();
        managerMinimumBalanceRequirement = manager_.minimumBalanceRequirement();
    }

    /**
     * @notice Removes the vote manager
     */
    function removeVoteManager() external onlyOwner {
        require(manager != address(0), "Vote manager does not exist");

        // Ensure that all outstanding manager rewards are accounted for
        _updateManagerRewardsForAllGroups();

        // Withdraw the manager's pending withdrawal balance
        // TODO: Refactor withdrawal initiation procedure for managers by adding a
        // "removeManager" method to Vault that handles unlocking and withdrawing
        // and is manager agnostic (for when we have other types)
        // this._initiateWithdrawal(managerRewards, false);

        archive.dissociateVaultFromManager(manager);

        delete manager;
        delete managerCommission;
        delete managerRewards;
    }

    /**
     * @notice Updates managerRewards with the rewards accrued for a voted group
     * @param group A validator group with active votes placed by the vote manager
     * @return Updated manager rewards and active votes
     */
    function updateManagerRewardsForGroup(address group)
        public
        returns (uint256, uint256)
    {
        uint256 networkActiveVotes = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );

        // We *always* update manager rewards *before* revoking active votes, so network
        // active votes for a group should always be GTE to its locally-stored active votes
        assert(networkActiveVotes >= activeVotes[group]);

        // Calculate the difference between the network and locally-stored active votes for
        // a group, to get the amount of rewards that have accrued since the last update
        FixidityLib.Fraction memory rewardsAccrued = FixidityLib.subtract(
            FixidityLib.newFixed(networkActiveVotes),
            FixidityLib.newFixed(activeVotes[group])
        );

        // Add the manager's share of the accrued group rewards to the total
        managerRewards = managerRewards.add(
            rewardsAccrued
                .divide(FixidityLib.newFixed(100))
                .multiply(FixidityLib.newFixed(managerCommission))
                .fromFixed()
        );

        // Update locally-stored active votes to match the network's active votes
        // so that we only account for reward accrual from this point onward
        _updateActiveVotesForGroup(group);

        return (managerRewards, activeVotes[group]);
    }

    function _updateManagerRewardsForAllGroups() internal {
        address[] memory groups = _getGroupsVoted();

        for (uint256 i = 0; i < groups.length; i += 1) {
            updateManagerRewardsForGroup(groups[i]);
        }
    }

    function _calculateManagerRewards(address group)
        internal
        view
        returns (uint256)
    {
        uint256 networkActiveVotes = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );

        // Calculate the difference between the live and local active votes
        // to get the amount of rewards accrued for this group
        FixidityLib.Fraction memory rewardsAccrued = FixidityLib.subtract(
            FixidityLib.newFixed(networkActiveVotes),
            FixidityLib.newFixed(activeVotes[group])
        );

        uint256 groupRewards = rewardsAccrued
            .divide(FixidityLib.newFixed(100))
            .multiply(FixidityLib.newFixed(managerCommission))
            .fromFixed();

        return groupRewards;
    }

    /**
     * @notice Fetch the list of groups with active votes from this vault
     * @return Array of group addresses
     */
    function _getGroupsVoted() internal view returns (address[] memory) {
        return election.getGroupsVotedForByAccount(address(this));
    }

    /**
     * @notice Updates local active votes to match the network's for a group
     * @notice Should only used when there aren't any manager rewards to distribute
     * @param group A validator group with active votes placed by the vote manager
     * @return Updated active votes
     */
    function _updateActiveVotesForGroup(address group)
        internal
        returns (uint256)
    {
        uint256 networkActiveVotes = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );

        // Update activeVotes for group
        activeVotes[group] = networkActiveVotes;

        return activeVotes[group];
    }

    function _revokePending(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) private returns (uint256) {
        // Validates group and revoke amount (cannot be zero or greater than pending votes)
        election.revokePending(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );

        return election.getPendingVotesForGroupByAccount(group, address(this));
    }

    function _revokeActive(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) private returns (uint256) {
        // Distribute rewards before activating votes, to protect the manager from loss of rewards
        updateManagerRewardsForGroup(group);

        election.revokeActive(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );

        return _updateActiveVotesForGroup(group);
    }

    function _revokeVotesEntirelyForGroups() internal {
        address[] memory groups = _getGroupsVoted();

        for (uint256 i = 0; i < groups.length; i += 1) {
            uint256 groupActiveVotes = election.getActiveVotesForGroupByAccount(
                groups[i],
                address(this)
            );
            uint256 groupPendingVotes = election
                .getPendingVotesForGroupByAccount(groups[i], address(this));

            if (groupPendingVotes > 0) {
                (address lesser, address greater) = archive.findLesserAndGreater(
                    groups[i],
                    groupPendingVotes,
                    true
                );

                _revokePending(
                    groups[i],
                    groupPendingVotes,
                    lesser,
                    greater,
                    i
                );
            }

            if (groupActiveVotes > 0) {
                (address lesser, address greater) = archive.findLesserAndGreater(
                    groups[i],
                    groupActiveVotes,
                    true
                );

                _revokeActive(groups[i], groupActiveVotes, lesser, greater, i);
            }
        }
    }

    function _revokeVotesProportionatelyForGroups(uint256 amount)
        internal
        returns (uint256)
    {
        address[] memory groups = _getGroupsVoted();
        uint256 totalVotes = election.getTotalVotesByAccount(address(this));
        uint256 totalRevoked = 0;

        for (uint256 i = 0; i < groups.length; i++) {
            uint256 groupActiveVotes = election.getActiveVotesForGroupByAccount(
                groups[i],
                address(this)
            );
            uint256 groupPendingVotes = election
                .getPendingVotesForGroupByAccount(groups[i], address(this));

            uint256 totalRevokeAmount = groupPendingVotes
                .add(groupActiveVotes)
                .mul(amount)
                .div(totalVotes);

            totalRevoked = totalRevoked.add(totalRevokeAmount);

            // Try to revoke the pending votes first whenever available
            if (groupPendingVotes > 0) {
                uint256 pendingRevokeAmount = (
                    totalRevokeAmount <= groupPendingVotes
                        ? totalRevokeAmount
                        : groupPendingVotes
                );
                (address lesser, address greater) = archive.findLesserAndGreater(
                    groups[i],
                    pendingRevokeAmount,
                    true
                );

                _revokePending(
                    groups[i],
                    pendingRevokeAmount,
                    lesser,
                    greater,
                    i
                );
                totalRevokeAmount = totalRevokeAmount.sub(pendingRevokeAmount);
            }

            // If there's any remaining votes need to be revoked, continue with the active ones
            if (totalRevokeAmount > 0) {
                (address lesser, address greater) = archive.findLesserAndGreater(
                    groups[i],
                    totalRevokeAmount,
                    true
                );

                _revokeActive(groups[i], totalRevokeAmount, lesser, greater, i);
            }
        }

        return totalRevoked;
    }

    /**
     * @notice Adds votes to an eligible validator group
     * @param group An eligible validator group
     * @param amount The amount of votes to place for this group
     * @param adjacentGroupWithLessVotes List of adjacent eligible validator groups with less votes
     * @param adjacentGroupWithMoreVotes List of adjacent eligible validator groups with more votes
     */
    function vote(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes
    ) external onlyVoteManager {
        // Validates group eligibility, sufficient vote amount, and group voting limit
        election.vote(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes
        );
    }

    /**
     * @notice Activates pending votes for a validator group
     * @param group A validator group
     * @return The current active votes for the group
     */
    function activate(address group) public onlyVoteManager returns (uint256) {
        // Distribute rewards before activating votes, to prevent them from being considered as rewards
        updateManagerRewardsForGroup(group);

        // Validates pending vote epoch and non-zero vote amount
        election.activate(group);

        return _updateActiveVotesForGroup(group);
    }

    /**
     * @notice Revokes active votes for a validator group
     * @param group A validator group
     * @param amount The amount of active votes to revoke
     * @param adjacentGroupWithLessVotes List of adjacent eligible validator groups with less votes
     * @param adjacentGroupWithMoreVotes List of adjacent eligible validator groups with more votes
     * @param accountGroupIndex Index of the group for this vault's account
     * @return The current active votes for the group
     */
    function revokeActive(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) public onlyVoteManager returns (uint256) {
        _revokeActive(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );
    }

    /**
     * @notice Revokes pending votes for a validator group
     * @param group A validator group
     * @param amount The amount of pending votes to revoke
     * @param adjacentGroupWithLessVotes List of adjacent eligible validator groups with less votes
     * @param adjacentGroupWithMoreVotes List of adjacent eligible validator groups with more votes
     * @param accountGroupIndex Index of the group for this vault's account
     * @return The current pending votes for the group
     */
    function revokePending(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) public onlyVoteManager returns (uint256) {
        _revokePending(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );
    }
}
