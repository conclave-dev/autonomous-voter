// contracts/Bank.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/StandaloneERC20.sol";

import "./celo/common/libraries/UsingPrecompiles.sol";
import "./celo/common/UsingRegistry.sol";
import "./modules/RewardManager.sol";
import "./Vault.sol";
import "./Portfolio.sol";

/**
 * @title VM contract to manage token related functionalities
 *
 */
contract Bank is
    Ownable,
    StandaloneERC20,
    UsingRegistry,
    UsingPrecompiles,
    RewardManager
{
    using SafeMath for uint256;

    // # of seed AV tokens per Vault
    uint256 public constant seedCapacity = 1000;
    // # of minted AV tokens per CELO
    uint256 public constant seedRatio = 1;

    // Seconds AV tokens are frozen post-mint
    // NOTE: Only modifiable seed parameter
    uint256 public seedFreezeDuration;

    struct FrozenTokens {
        uint256 amount;
        uint256 frozenUntil;
    }

    mapping(address => uint256) private _frozenBalance;
    mapping(address => uint256) internal totalSeeded;
    mapping(address => FrozenTokens[]) internal frozenTokens;

    ILockedGold public lockedGold;
    Portfolio public portfolio;

    function initializeBank(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address[] memory minters,
        address[] memory pausers,
        uint256 seedFreezeDuration_,
        address registry_
    ) public initializer {
        Ownable.initialize(msg.sender);
        StandaloneERC20.initialize(name_, symbol_, decimals_, minters, pausers);
        UsingRegistry.initializeRegistry(msg.sender, registry_);

        getAccounts().createAccount();
        lockedGold = getLockedGold();

        seedFreezeDuration = seedFreezeDuration_;
    }

    // Requires that the msg.sender be the vault owner
    modifier onlyVaultOwner(Vault vault) {
        require(msg.sender == vault.owner(), "Must be vault owner");
        _;
    }

    /**
     * @notice Fetch the total amount of frozen balance of the specified account
     * @param account Address of the account to be queried
     */
    function frozenBalanceOf(address account) public view returns (uint256) {
        return _frozenBalance[account];
    }

    /**
     * @notice Sets the value of `seedFreezeDuration`
     * @param duration Seconds AV tokens are frozen post-mint
     */
    function setSeedFreezeDuration(uint256 duration) external onlyOwner {
        require(duration > 0, "Invalid duration");
        seedFreezeDuration = duration;
    }

    function setPortfolio(Portfolio portfolio_) external onlyOwner {
        portfolio = portfolio_;
    }

    function setRewardExpiration(uint256 rewardExpiration_) external onlyOwner {
        rewardExpiration = rewardExpiration_;
    }

    function _addDepositMutation(address account, uint256 amount) internal {
        uint256 currentEpoch = getEpochNumber();

        BalanceMutation storage mutation = balanceMutations[currentEpoch];
        mutation.totalDeposit = mutation.totalDeposit.add(amount);
        mutation.accountMutations[account].deposit = mutation
            .accountMutations[account]
            .deposit
            .add(amount);
    }

    function _addWithdrawalMutation(address account, uint256 amount) internal {
        uint256 currentEpoch = getEpochNumber();

        BalanceMutation storage mutation = balanceMutations[currentEpoch];
        mutation.totalWithdrawal = mutation.totalWithdrawal.add(amount);
        mutation.accountMutations[account].withdrawal = mutation
            .accountMutations[account]
            .withdrawal
            .add(amount);
    }

    function _addTransferMutations(
        address from,
        address to,
        uint256 amount
    ) internal {
        _addDepositMutation(to, amount);
        _addWithdrawalMutation(from, amount);
    }

    /**
     * @notice Mints AV tokens for a vault
     * @param vault Vault contract deployed and owned by `msg.sender`
     */
    function seed(Vault vault) external payable onlyVaultOwner(vault) {
        require(msg.value > 0, "Invalid amount");
        address vaultAddress = address(vault);

        // Calculate the to-be minted tokens and verify that the total seeded would still be within the capacity/limit
        uint256 mintAmount = msg.value.mul(seedRatio);
        require(
            totalSeeded[msg.sender].add(mintAmount) <=
                seedCapacity.mul(decimals()),
            "Seed capacity exceeded"
        );

        // Mint tokens proportionally based on the currently set ratio and the specified amount
        _mint(vaultAddress, mintAmount);
        _addDepositMutation(vaultAddress, mintAmount);

        totalSeeded[msg.sender] = totalSeeded[msg.sender].add(mintAmount);
        _frozenBalance[vaultAddress] = _frozenBalance[vaultAddress].add(
            mintAmount
        );

        // Freeze the newly minted tokens and set it to be unlockable based on the currently set freezing duration
        frozenTokens[vaultAddress].push(
            FrozenTokens(mintAmount, now.add(seedFreezeDuration))
        );

        // Proceed to lock the newly transferred CELO to be used for voting in CELO
        lockedGold.lock.value(msg.value)();
    }

    /**
     * @notice Unfreeze the specified account's frozen tokens if available
     * @param index Index of the frozen tokens record to be unfrozen
     */
    function unfreezeTokens(Vault vault, uint256 index)
        external
        onlyVaultOwner(vault)
    {
        address vaultAddress = address(vault);
        FrozenTokens[] storage userFrozenTokens = frozenTokens[vaultAddress];
        require(index < userFrozenTokens.length, "Invalid index specified");

        FrozenTokens memory frozenToken = userFrozenTokens[index];
        require(
            frozenToken.frozenUntil <= now,
            "Unable to unfreeze frozen tokens"
        );

        _frozenBalance[vaultAddress] = _frozenBalance[vaultAddress].sub(
            frozenToken.amount
        );

        // Swap only if needed (the deleted index is not in the last index)
        uint256 lastIndex = userFrozenTokens.length - 1;
        if (index != lastIndex) {
            userFrozenTokens[index] = userFrozenTokens[lastIndex];
        }

        // Resize the array to 'remove' the record
        userFrozenTokens.length--;
    }

    /**
     * @notice Fetch a frozen token record of the specified account and index
     * @param account Address of the account to be queried
     * @param index Index of the token reccord to be queried
     */
    function getFrozenTokenDetail(address account, uint256 index)
        external
        view
        returns (uint256, uint256)
    {
        FrozenTokens[] memory userFrozenTokens = frozenTokens[account];
        require(index < userFrozenTokens.length, "Invalid index specified");
        uint256 amount = userFrozenTokens[index].amount;
        uint256 frozenUntil = userFrozenTokens[index].frozenUntil;
        return (amount, frozenUntil);
    }

    /**
     * @notice Fetch the total number of frozen token records of the specified account
     * @param account Address of the account to be queried
     */
    function getFrozenTokenCount(address account)
        external
        view
        returns (uint256)
    {
        return frozenTokens[account].length;
    }

    // Checkpoints to make sure the account has enough unfrozen tokens
    function _checkAvailableTokens(address account, uint256 amount)
        internal
        view
    {
        // Verify if the user has sufficient unfrozen tokens
        require(
            balanceOf(account).sub(_frozenBalance[account]) >= amount,
            "Insufficient unfrozen tokens"
        );
    }

    // Override ERC20's `transfer` to include checkpoint for preventing frozenTokens from being transferred
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _checkAvailableTokens(msg.sender, amount);
        // Call internal `_transfer` since we can't pass identical `msg.sender` into ERC20's `transfer` method
        _transfer(msg.sender, recipient, amount);
        _addTransferMutations(msg.sender, recipient, amount);
        return true;
    }

    // Override ERC20's `transferFrom` to include checkpoint for preventing frozenTokens from being transferred
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        _checkAvailableTokens(sender, amount);
        ERC20.transferFrom(sender, recipient, amount);
        _addTransferMutations(sender, recipient, amount);
        return true;
    }

    // Custom transfer method to allow vault owners to transfer unfrozen (and unlocked) tokens regardless of allowance
    function transferFromVault(
        Vault vault,
        address recipient,
        uint256 amount
    ) external onlyVaultOwner(vault) {
        // Prevent transfer if the vault's owner is an upvoter (preventing duplicate upvotes with the same tokens)
        require(
            portfolio.isUpvoter(msg.sender) == false,
            "Caller upvoted a proposal - cannot transfer tokens yet"
        );
        _checkAvailableTokens(address(vault), amount);
        _transfer(address(vault), recipient, amount);
        _addTransferMutations(address(vault), recipient, amount);
    }

    function updateRewardBalance() public {
        uint256 currentEpoch = getEpochNumber();
        uint256 previousEpoch = currentEpoch - 1;

        require(
            rewardBalances[currentEpoch] == 0,
            "Reward balance has already been updated"
        );

        uint256 currentBalance = lockedGold.getAccountTotalLockedGold(
            address(this)
        );
        uint256 previousBalance = lockedGoldBalances[previousEpoch];
        rewardBalances[currentEpoch] = previousBalance.sub(currentBalance);
        lockedGoldBalances[currentEpoch] = currentBalance;

        _mint(address(this), rewardBalances[currentEpoch]);

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
        uint256 vaultBalance = balanceOf(vaultAddress);
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

        _transfer(address(this), vaultAddress, totalOwedRewards);
    }
}
