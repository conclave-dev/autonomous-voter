// contracts/RewardManager.sol

pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./celo/common/libraries/UsingPrecompiles.sol";
import "./Vault.sol";
import "./Bank.sol";

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

    // Stores last updated epoch as well as the balances of both the Bank's lockedGold
    // and accrued reward on each epoch
    struct BankBalance {
        uint256 lastRewardUpdatedEpoch;
        mapping(uint256 => uint256) lockedGoldBalances;
        mapping(uint256 => uint256) rewardBalances;
    }

    BankBalance bankBalance;
    // Tracks the amount of deposit and withdrawal of all accounts for each epoch
    mapping(uint256 => BalanceMutation) internal balanceMutations;
    // Tracks the total supply of tokens for each epoch
    mapping(uint256 => uint256) internal tokenSupplies;
    // Tracks the epoch number where users last claimed their rewards
    mapping(address => uint256) internal lastClaimedEpochs;

    // Stores the duration in which rewards would no longer be available to claim
    uint256 public CELORewardExpiration;
    // Stores the percentage of reward from the epoch rewards to be distributed to token holders
    uint256 public CELOCompoundingPercent;

    Bank public bank;

    // Requires that the msg.sender be the vault owner
    modifier onlyVaultOwner(Vault vault) {
        require(msg.sender == vault.owner(), "Must be vault owner");
        _;
    }

    // Requires that the msg.sender be the Bank
    modifier onlyBank() {
        require(msg.sender == address(bank), "Only available to the Bank");
        _;
    }

    function initialize(
        Bank bank_,
        uint256 rewardExpiration,
        uint256 holderRewardPercentage
    ) public initializer {
        Ownable.initialize(msg.sender);

        bank = bank_;
        CELORewardExpiration = rewardExpiration;
        CELOCompoundingPercent = holderRewardPercentage;

        // Initialize the balance of the first tracked epoch
        bankBalance.lockedGoldBalances[getEpochNumber()] = bank
            .totalLockedGold();
    }

    function setBank(Bank bank_) external onlyOwner {
        bank = bank_;
    }

    function setCeloRewardExpiration(uint256 rewardExpiration_)
        external
        onlyOwner
    {
        require(
            rewardExpiration_ > 0,
            "Reward expiration must be set to at least 1 epoch"
        );
        CELORewardExpiration = rewardExpiration_;
    }

    function setCeloCompoundingPercent(uint256 holderRewardPercentage_)
        external
        onlyOwner
    {
        require(
            holderRewardPercentage_ > 0 && holderRewardPercentage_ < 100,
            "Reward percentage must be between 1 and 99 percents"
        );
        CELOCompoundingPercent = holderRewardPercentage_;
    }

    // Handle incoming deposit request on Bank by keep tracking the mutation
    function addDepositMutation(address account, uint256 amount)
        public
        onlyBank
    {
        uint256 currentEpoch = getEpochNumber();

        if (bankBalance.lastRewardUpdatedEpoch < currentEpoch - 1) {
            updateRewardBalance();
        }

        BalanceMutation storage mutation = balanceMutations[currentEpoch];
        mutation.totalDeposit = mutation.totalDeposit.add(amount);
        mutation.accountMutations[account].deposit = mutation
            .accountMutations[account]
            .deposit
            .add(amount);
    }

    // Handle incoming withdrawal request on Bank by keep tracking the mutation
    function addWithdrawalMutation(address account, uint256 amount)
        public
        onlyBank
    {
        uint256 currentEpoch = getEpochNumber();

        if (bankBalance.lastRewardUpdatedEpoch < currentEpoch - 1) {
            updateRewardBalance();
        }

        BalanceMutation storage mutation = balanceMutations[currentEpoch];
        mutation.totalWithdrawal = mutation.totalWithdrawal.add(amount);
        mutation.accountMutations[account].withdrawal = mutation
            .accountMutations[account]
            .withdrawal
            .add(amount);
    }

    // Update internal historical data to keep track of (and calculate) holder rewards each epoch
    function updateRewardBalance() public {
        uint256 currentEpoch = getEpochNumber();
        uint256 previousEpoch = currentEpoch - 1;

        require(
            bankBalance.lastRewardUpdatedEpoch < currentEpoch - 1,
            "Reward balance has already been updated"
        );

        // Get current lockedGold in Bank
        uint256 currentBalance = bank.totalLockedGold();

        // Calculate the actual reward acquired by Bank
        // by comparing it with the previous epoch's total lockedGold
        // and also considering deposits/withdrawals in the previous epoch
        // then get the actual amount allocated to holders
        if (bankBalance.lockedGoldBalances[previousEpoch] > 0) {
            uint256 previousBalance = bankBalance
                .lockedGoldBalances[previousEpoch];
            uint256 reward = currentBalance
                .sub(previousBalance)
                .sub(balanceMutations[previousEpoch].totalDeposit)
                .add(balanceMutations[previousEpoch].totalWithdrawal);
            bankBalance.rewardBalances[previousEpoch] = reward
                .mul(CELOCompoundingPercent)
                .div(100);
        } else {
            // In the rare event of technical issue which cause an epoch to be skipped/not updated
            // the system will not be giving out any reward
            bankBalance.rewardBalances[previousEpoch] = 0;
        }

        // Save the calculated lockedGold balance for current epoch
        bankBalance.lockedGoldBalances[currentEpoch] = currentBalance;

        // Update the token supply for the previous epoch
        // by deducting any deposit performed
        tokenSupplies[previousEpoch] = bank.totalSupply().sub(
            balanceMutations[previousEpoch].totalDeposit
        );

        // Immediately mint AV tokens according to the amount of epoch rewards allocated to holders
        bank.mintEpochRewards(bankBalance.rewardBalances[previousEpoch]);

        bankBalance.lastRewardUpdatedEpoch = previousEpoch;
    }

    // Called by token holders to claim their outstanding (and still available) rewards
    function claimReward(Vault vault) public onlyVaultOwner(vault) {
        address vaultAddress = address(vault);
        uint256 currentEpoch = getEpochNumber();
        uint256 lastClaimed = lastClaimedEpochs[vaultAddress];

        require(
            lastClaimed < currentEpoch - 1,
            "All available rewards have been claimed"
        );

        if (bankBalance.lastRewardUpdatedEpoch < currentEpoch - 1) {
            updateRewardBalance();
        }

        uint256 startingEpoch = (
            currentEpoch - CELORewardExpiration > lastClaimed + 1
                ? currentEpoch - CELORewardExpiration
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
            uint256 reward = ownershipPercentage
                .mul(bankBalance.rewardBalances[i])
                .div(100);

            AccountBalanceMutation memory mutation = balanceMutations[i]
                .accountMutations[vaultAddress];
            vaultBalance = vaultBalance.add(reward).add(mutation.deposit).sub(
                mutation.withdrawal
            );
            totalOwedRewards = totalOwedRewards.add(reward);
        }

        lastClaimedEpochs[vaultAddress] = currentEpoch - 1;

        bank.transferEpochRewards(vault, totalOwedRewards);
    }

    function getEpochRewardBalance(uint256 epoch)
        external
        view
        returns (uint256)
    {
        return bankBalance.rewardBalances[epoch];
    }
}
