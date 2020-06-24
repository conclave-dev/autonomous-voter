pragma solidity ^0.5.8;

import "../Vault.sol";

contract MockVault is Vault {
    using SafeMath for uint256;
    using LinkedList for LinkedList.List;

    function setLocalActiveVotesForGroup(address group, uint256 amount) public {
        activeVotes[group] = amount;
    }

    function setCommission(uint256 percentage) public {
        managerCommission = percentage;
    }

    function setManagerMinimumBalanceRequirement(uint256 minimumBalance)
        public
    {
        managerMinimumBalanceRequirement = minimumBalance;
    }

    function getVotedGroups() public view returns (address[] memory) {
        address[] memory groups = _getGroupsVoted();
        return groups;
    }

    function calculateVotingManagerRewards(address group)
        public
        view
        returns (uint256)
    {
        return _calculateManagerRewards(group);
    }

    function reset() external {
        // Reset group related data
        address[] memory groups = _getGroupsVoted();
        for (uint256 i = 0; i < groups.length; i++) {
            delete activeVotes[groups[i]];
        }
    }

    /**
     * @notice Creates a pending withdrawal and generates a hash for verification
     */
    function _initiateWithdrawal(uint256 amount, bool forOwner) internal {
        // @TODO: Consider creating 2 separate "initiate withdrawal" methods in order to
        // thoroughly validate based on whether it's the owner or manager

        // Only the owner or vote manager can call this method
        require(
            msg.sender == owner() || msg.sender == manager,
            "Not authorized"
        );

        address withdrawalRecipient = forOwner ? owner() : manager;

        // Generate a hash for withdrawal-time verification
        pendingWithdrawals.push(
            keccak256(
                abi.encodePacked(
                    // Account that should be receiving the withdrawal funds
                    withdrawalRecipient,
                    // Pending withdrawal amount
                    amount,
                    // Pending withdrawal timestamp
                    block.timestamp
                )
            )
        );
    }

    function removeVoteManager() external onlyOwner {
        require(manager != address(0), "Vote manager does not exist");

        // Ensure that all outstanding manager rewards are accounted for
        updateManagerRewardsForGroups();

        // Withdraw the manager's pending withdrawal balance
        _initiateWithdrawal(managerRewards, false);

        Manager(manager).deregisterVault();

        delete manager;
        delete managerCommission;
        delete managerRewards;
    }
}
