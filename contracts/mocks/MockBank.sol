// contracts/mocks/MockBank.sol

pragma solidity ^0.5.8;

import "../Bank.sol";

contract MockBank is Bank {
    function reset() public {
        lockedGold.unlock(lockedGold.getAccountTotalLockedGold(address(this)));
        _transfer(address(this), address(1), balanceOf(address(this)));
    }

    // Mocked function to simulate getting epoch rewards from CELO
    function mockEpochReward() public payable {
        lockedGold.lock.value(msg.value)();
    }
}
