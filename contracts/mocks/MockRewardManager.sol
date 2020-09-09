// contracts/mocks/MockRewardManager.sol

pragma solidity ^0.5.8;

import "../RewardManager.sol";

contract MockRewardManager is RewardManager {
    function reset() public {
        // Clear all epoch states up to the next 20 epochs
        uint256 epoch = getEpochNumber();
        for (uint256 i = epoch; i < epoch + 20; i++) {
            delete lockedGoldBalances[i];
            delete rewardUpdateStates[i];
            delete rewardBalances[i];
            delete balanceMutations[i];
            delete tokenSupplies[i];
        }
    }
}
