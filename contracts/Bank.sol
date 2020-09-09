// contracts/Bank.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/StandaloneERC20.sol";

import "./celo/common/UsingRegistry.sol";
import "./RewardManager.sol";
import "./Vault.sol";
import "./Portfolio.sol";

/**
 * @title VM contract to manage token related functionalities
 *
 */
contract Bank is Ownable, StandaloneERC20, UsingRegistry {
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
    Portfolio internal portfolio;
    RewardManager internal rewardManager;

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

    // Requires that the msg.sender be the currently set RewardManager
    modifier onlyRewardManager() {
        require(
            msg.sender == address(rewardManager),
            "Only available to Reward Manager"
        );
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

    function setRewardManager(RewardManager rewardManager_) external onlyOwner {
        rewardManager = rewardManager_;
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

        totalSeeded[msg.sender] = totalSeeded[msg.sender].add(mintAmount);
        _frozenBalance[vaultAddress] = _frozenBalance[vaultAddress].add(
            mintAmount
        );

        // Freeze the newly minted tokens and set it to be unlockable based on the currently set freezing duration
        frozenTokens[vaultAddress].push(
            FrozenTokens(mintAmount, now.add(seedFreezeDuration))
        );

        // Notify the rewardManager for the deposit, must be called before locking the new gold
        rewardManager.addDepositMutation(vaultAddress, mintAmount);

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
        rewardManager.addTransferMutations(msg.sender, recipient, amount);
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
        rewardManager.addTransferMutations(sender, recipient, amount);
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
        rewardManager.addTransferMutations(address(vault), recipient, amount);
    }

    function totalLockedGold() external view returns (uint256) {
        return lockedGold.getAccountTotalLockedGold(address(this));
    }

    function mintEpochRewards(uint256 amount) external onlyRewardManager {
        _mint(address(this), amount);
    }

    function transferEpochRewards(Vault vault, uint256 amount)
        external
        onlyRewardManager
    {
        _transfer(address(this), address(vault), amount);
    }
}
