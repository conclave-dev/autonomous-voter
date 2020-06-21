// contracts/Vault.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../Archive.sol";
import "../Manager.sol";
import "../celo/governance/interfaces/IElection.sol";
import "../celo/governance/interfaces/ILockedGold.sol";
import "../celo/common/FixidityLib.sol";

contract VoteManagement is Ownable {
    using SafeMath for uint256;
    using FixidityLib for FixidityLib.Fraction;

    Archive public archive;
    IElection public election;
    ILockedGold public lockedGold;

    address public manager;
    uint256 public managerCommission;
    uint256 public managerRewards;
    mapping(address => uint256) public activeVotes;

    modifier onlyVoteManager() {
        require(msg.sender == manager, "Not the vote manager");
        _;
    }

    // Gets the Vault's nonvoting locked gold amount
    function getNonvotingBalance() public view returns (uint256) {
        return lockedGold.getAccountNonvotingLockedGold(address(this));
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

        manager_.registerVault();

        manager = address(manager_);
        managerCommission = manager_.commission();
    }

    /**
     * @notice Removes a vote manager
     */
    function removeVoteManager() external onlyOwner {
        require(manager != address(0), "Vote manager does not exist");

        Manager(manager).deregisterVault();

        manager = address(0);
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

        // Return current values if active votes has not increased (i.e. no rewards)
        if (networkActiveVotes <= activeVotes[group]) {
            return (managerRewards, activeVotes[group]);
        }

        // Calculate the difference between the live and local active votes
        // to get the amount of rewards accrued for this group
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

        _updateActiveVotesForGroup(group);

        return (managerRewards, activeVotes[group]);
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
    ) external onlyVoteManager returns (uint256) {
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
}
