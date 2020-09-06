// contracts/mocks/MockBank.sol

pragma solidity ^0.5.8;

import "../Bank.sol";

contract MockBank is Bank {
    // Mocked function to simulate getting epoch rewards from CELO
    function mockEpochReward() public payable {
        lockedGold.lock.value(msg.value)();
    }
}
