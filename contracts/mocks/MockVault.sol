// contracts/Vault.sol
pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../Vault.sol";
import "../Archive.sol";
import "../VaultManager.sol";
import "../celo/common/libraries/AddressLinkedList.sol";

contract MockVault is Vault {
    using SafeMath for uint256;
    using AddressLinkedList for LinkedList.List;

    VaultManagers private vaultManagers;
    Votes private votes;

    // For testing purposes
    mapping(address => uint256) public activeVotesWithoutRewards;
    uint256 public rewardSharePercentage;
    bool public initialized;

    function initialize(
        address mockRegistry_,
        Archive archive_,
        address owner_,
        address admin
    ) public payable initializer {
        Vault.initialize(mockRegistry_, archive_, owner_, admin);
        initialized = true;
    }

    function setActiveVotesWithoutRewardsForGroup(address group, uint256 amount)
        public
    {
        votes.activeVotesWithoutRewards[group] = amount;

        // For testing purposes
        activeVotesWithoutRewards[group] = amount;
    }

    function setRewardSharePercentage(uint256 percentage) public {
        vaultManagers.voting.rewardSharePercentage = percentage;

        // For testing purposes
        rewardSharePercentage = percentage;
    }

    /**
     * @notice Calculates the voting vault manager's rewards for a group
     * @param group A validator group with active votes placed by the voting vault manager
     * @return Manager's reward amount
     */
    function _calculateVotingManagerRewards(address group)
        internal
        view
        returns (uint256)
    {
        // totalRewardsAccrued = activeVotes (Celo) - activeVotesWithoutRewards (local)
        // vaultManagerRewards = (totalRewardsAccrued / 100) * rewardSharePercentage
        return
            election
                .getActiveVotesForGroupByAccount(group, address(this))
                .sub(votes.activeVotesWithoutRewards[group])
                .div(100)
                .mul(vaultManagers.voting.rewardSharePercentage);
    }
}
