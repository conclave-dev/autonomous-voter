// contracts/modules/RewardManager.sol

pragma solidity ^0.5.8;

contract RewardManager {
    // Stores both the total deposit and withdrawal amount of an account in an epoch
    struct AccountBalanceMutation {
        // Amount of token deposits/seeds accrued in a single epoch
        uint256 deposit;
        // Amount of token withdrawals/burns accrued in a single epoch
        uint256 withdrawal;
    }

    // Stores the grand total deposit and withdrawal amount for all accounts in an epoch
    // as well as keeping the record of each individual account record
    struct BalanceMutation {
        uint256 totalDeposit;
        uint256 totalWithdrawal;
        mapping(address => AccountBalanceMutation) accountMutations;
    }

    // Tracks the amount of lockedGold owned by the Bank for each epoch
    mapping(uint256 => uint256) internal lockedGoldBalances;
    // Tracks the amount of reward acquired by the Bank for each epoch
    mapping(uint256 => uint256) internal rewardBalances;
    // Tracks the amount of deposit and withdrawal of all accounts for each epoch
    mapping(uint256 => BalanceMutation) internal balanceMutations;
    // Tracks the total supply of tokens for each epoch
    mapping(uint256 => uint256) internal tokenSupplies;
    // Tracks the epoch number where users last claimed their rewards
    mapping(address => uint256) internal lastClaimedEpochs;

    // Stores the duration in which rewards would no longer be available to claim
    uint256 public rewardExpiration;
}
