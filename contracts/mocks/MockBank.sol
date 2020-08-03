// contracts/mocks/MockBank.sol
pragma solidity ^0.5.8;

import "../Bank.sol";

contract MockBank is Bank {
    function removeLockedToken(address account) external {
        delete lockedTokens[account];
    }

    function reset() external {
        initialCycleEpoch = 0;
    }
}
