// contracts/RewardManager.sol

pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./celo/common/libraries/UsingPrecompiles.sol";
import "./Bank.sol";
import "./Vault.sol";

contract RewardManager is Ownable, UsingPrecompiles {
    using SafeMath for uint256;

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
    mapping(uint256 => uint256) lockedGoldBalances;
    // Tracks the amount of reward acquired by the Bank for each epoch
    mapping(uint256 => uint256) rewardBalances;
    // Tracks the amount of deposit and withdrawal of all accounts for each epoch
    mapping(uint256 => BalanceMutation) balanceMutations;
    // Tracks the total supply of tokens for each epoch
    mapping(uint256 => uint256) tokenSupplies;
    // Tracks the epoch number where users last claimed their rewards
    mapping(address => uint256) lastClaimedEpochs;

    Bank public bank;

    // Stores the duration in which rewards would no longer be available to claim
    uint256 public rewardExpiration;

    modifier onlyVaultOwner(Vault vault) {
        require(msg.sender == vault.owner(), "Must be vault owner");
        _;
    }

    function initialize(Bank bank_, uint256 rewardExpiration_)
        public
        initializer
    {
        Ownable.initialize(msg.sender);

        bank = bank_;
        rewardExpiration = rewardExpiration_;
    }

    function setBank(Bank bank_) external onlyOwner {
        bank = bank_;
    }

    function setRewardExpiration(uint256 rewardExpiration_) external onlyOwner {
        rewardExpiration = rewardExpiration_;
    }

    function updateRewardBalance() public {
        uint256 currentEpoch = getEpochNumber();
        uint256 previousEpoch = currentEpoch - 1;

        require(
            rewardBalances[currentEpoch] == 0,
            "Reward balance has already been updated"
        );

        uint256 currentBalance = bank.totalLockedGold();
        uint256 previousBalance = lockedGoldBalances[previousEpoch];
        rewardBalances[currentEpoch] = previousBalance.sub(currentBalance);

        bank.mintEpochRewards(rewardBalances[currentEpoch]);

        tokenSupplies[previousEpoch] = tokenSupplies[previousEpoch]
            .add(balanceMutations[previousEpoch].totalDeposit)
            .sub(balanceMutations[previousEpoch].totalWithdrawal);

        tokenSupplies[currentEpoch] = tokenSupplies[previousEpoch].add(
            rewardBalances[currentEpoch]
        );
    }

    function claimReward(Vault vault) public onlyVaultOwner(vault) {
        address vaultAddress = address(vault);
        uint256 currentEpoch = getEpochNumber();
        uint256 lastClaimed = lastClaimedEpochs[vaultAddress];

        require(
            lastClaimed < currentEpoch - 1,
            "All available rewards have been claimed"
        );

        if (rewardBalances[currentEpoch] == 0) {
            updateRewardBalance();
        }

        uint256 startingEpoch = (
            currentEpoch - rewardExpiration > lastClaimed + 1
                ? currentEpoch - rewardExpiration
                : lastClaimed + 1
        );
        uint256 vaultBalance = bank.balanceOf(vaultAddress);
        uint256 totalOwedRewards = 0;

        for (uint256 i = currentEpoch; i >= startingEpoch; i -= 1) {
            AccountBalanceMutation memory mutation = balanceMutations[i]
                .accountMutations[vaultAddress];
            vaultBalance = vaultBalance.sub(mutation.deposit).add(
                mutation.withdrawal
            );
        }

        for (uint256 i = startingEpoch; i < currentEpoch; i += 1) {
            uint256 ownershipPercentage = vaultBalance.mul(100).div(
                tokenSupplies[i]
            );
            uint256 reward = ownershipPercentage.mul(rewardBalances[i]).div(
                100
            );

            AccountBalanceMutation memory mutation = balanceMutations[i]
                .accountMutations[vaultAddress];
            vaultBalance = vaultBalance.add(reward).add(mutation.deposit).sub(
                mutation.withdrawal
            );
            totalOwedRewards = totalOwedRewards.add(reward);

            lastClaimedEpochs[vaultAddress] = currentEpoch - 1;
        }

        bank.claimRewardForVault(vault, totalOwedRewards);
    }
}
