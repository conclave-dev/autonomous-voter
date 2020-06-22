pragma solidity ^0.5.8;

import "../Vault.sol";

contract MockVault is Vault {
    function setLocalActiveVotesForGroup(address group, uint256 amount) public {
        activeVotes[group] = amount;
    }

    function setCommission(uint256 percentage) public {
        managerCommission = percentage;
    }
}
