// contracts/Vault.sol
pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../Vault.sol";
import "../Archive.sol";
import "../Manager.sol";
import "../celo/common/libraries/AddressLinkedList.sol";

contract MockVault is Vault {
    using SafeMath for uint256;
    using AddressLinkedList for LinkedList.List;

    function setActiveVotesWithoutRewardsForGroup(address group, uint256 amount)
        public
    {
        activeVotes[group] = amount;
    }

    function setCommission(uint256 percentage) public {
        managerCommission = percentage;
    }
}
