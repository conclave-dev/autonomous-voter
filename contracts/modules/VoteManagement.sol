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
    mapping(address => uint256) activeVotes;

    modifier onlyVoteManager() {
        require(msg.sender == manager, "Not the vote manager");
        _;
    }

    modifier onlyGroupWithVotes(address group) {
        require(activeVotes[group] > 0, "Group does not have votes");
        _;
    }

    modifier postRevokeCleanup(address group) {
        // Execute function first
        _;

        // Cleans up after vote-revoking method calls, by removing the group if it doesn't have votes
        if (
            election.getTotalVotesForGroupByAccount(group, address(this)) == 0
        ) {
            delete activeVotes[group];
        }
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
            "Voting vault manager_ is invalid"
        );
        require(manager == address(0), "Voting vault manager_ already exists");

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
     * @notice Calculates the vote manager's rewards for a group
     * @param group A validator group with active votes placed by the vote manager
     * @return Manager's reward amount
     */
    function calculateManagerRewards(address group)
        public
        view
        returns (uint256)
    {
        FixidityLib.Fraction memory networkActiveVotes = FixidityLib.newFixed(
            election.getActiveVotesForGroupByAccount(group, address(this))
        );
        FixidityLib.Fraction memory localActiveVotes = FixidityLib.newFixed(
            activeVotes[group]
        );
        FixidityLib.Fraction memory rewardsAccrued = FixidityLib.subtract(
            networkActiveVotes,
            localActiveVotes
        );
        FixidityLib.Fraction memory rewardsAccruedPercent = FixidityLib.divide(
            rewardsAccrued,
            FixidityLib.newFixed(100)
        );

        // rewardsAccrued = networkActiveVotes - localActiveVotes
        // voteManagerRewards = (rewardsAccrued / 100) * managerCommission
        return
            FixidityLib
                .multiply(
                rewardsAccruedPercent,
                FixidityLib.newFixed(managerCommission)
            )
                .fromFixed();
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
     * @notice Activates pending votes for a validator group that this vault is currently voting for
     * @param group A validator group
     */
    function activate(address group)
        public
        onlyVoteManager
        onlyGroupWithVotes(group)
    {
        // Save pending votes amount before activation attempt
        uint256 pendingVotes = election.getPendingVotesForGroupByAccount(
            group,
            address(this)
        );

        // activate validates pending vote epoch and non-zero vote amount
        election.activate(group);

        // Increment activeVotes by activated pending votes instead of
        // Celo active votes in order to retain reward accrual difference
        activeVotes[group] = activeVotes[group] + pendingVotes;
    }

    /**
     * @notice Revokes active votes for a validator group that this vault is currently voting for
     * @param group A validator group
     * @param amount The amount of active votes to revoke
     * @param adjacentGroupWithLessVotes List of adjacent eligible validator groups with less votes
     * @param adjacentGroupWithMoreVotes List of adjacent eligible validator groups with more votes
     * @param accountGroupIndex Index of the group for this vault's account
     */
    function revokeActive(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) external onlyVoteManager onlyGroupWithVotes(group) {
        require(
            activeVotes[group] ==
                election.getActiveVotesForGroupByAccount(group, address(this)),
            "Voting manager rewards need to be distributed first"
        );

        _revokeActive(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );
    }

    /**
     * @notice Revokes pending votes for a validator group that this vault is currently voting for
     * @param group A validator group
     * @param amount The amount of pending votes to revoke
     * @param adjacentGroupWithLessVotes List of adjacent eligible validator groups with less votes
     * @param adjacentGroupWithMoreVotes List of adjacent eligible validator groups with more votes
     * @param accountGroupIndex Index of the group for this vault's account
     */
    function revokePending(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) public {
        // Validates group and revoke amount (cannot be zero or greater than pending votes)
        election.revokePending(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );
    }

    // Internal method to allow the owner to manipulate group votes for certain operations
    // Primarily called by the vault manager-only method of the same name without leading underscore
    function _revokeActive(
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) internal postRevokeCleanup(group) {
        // Validates group and revoke amount (cannot be zero or greater than active votes)
        election.revokeActive(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );

        activeVotes[group] = election.getActiveVotesForGroupByAccount(
            group,
            address(this)
        );
    }
}
