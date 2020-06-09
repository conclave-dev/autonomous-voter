// contracts/interfaces/IStrategy.sol
pragma solidity ^0.5.8;


interface IStrategy {
    function getRewardSharePercentage() external view returns (uint256);

    function getMinimumManagedGold() external view returns (uint256);

    function registerVault(uint256 strategyIndex, uint256 amount) external;
}
