// contracts/celo/governance/interfaces/IEpochRewards.sol
pragma solidity ^0.5.8;


interface IEpochRewards {
    function calculateTargetEpochRewards() external view returns (uint256, uint256, uint256, uint256);
    function getTargetVoterRewards() external view returns (uint256);
    function getRewardsMultiplier() external view returns (uint256);
}
