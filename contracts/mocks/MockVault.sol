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
        groupActiveVotesWithoutRewards[group] = amount;
    }

    function setRewardSharePercentage(uint256 percentage) public {
        votingManager.rewardSharePercentage = percentage;
    }
}
