// contracts/Bank.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/StandaloneERC20.sol";

import "./Vault.sol";

/**
 * @title VM contract to manage token related functionalities
 *
 */
contract Bank is Ownable, StandaloneERC20 {
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
        uint256 unlockedAt;
    }

    mapping(address => uint256) internal totalSeeded;
    mapping(address => FrozenTokens[]) internal frozenTokens;

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address[] memory minters,
        address[] memory pausers,
        uint256 seedFreezeDuration_
    ) public initializer {
        Ownable.initialize(msg.sender);
        StandaloneERC20.initialize(name_, symbol_, decimals_, minters, pausers);
        seedFreezeDuration = seedFreezeDuration_;
    }

    // Requires that the msg.sender be the vault owner
    modifier onlyVaultOwner(Vault vault) {
        require(msg.sender == vault.owner(), "Must be vault owner");
        _;
    }

    /**
     * @notice Sets the value of `seedFreezeDuration`
     * @param duration Seconds AV tokens are frozen post-mint
     */
    function setSeedFreezeDuration(uint256 duration) external onlyOwner {
        require(duration > 0, "Invalid duration");
        seedFreezeDuration = duration;
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

        // Freeze the newly minted tokens and set it to be unlockable based on the currently set freezing duration
        frozenTokens[vaultAddress].push(
            FrozenTokens(mintAmount, now.add(seedFreezeDuration))
        );
    }

    /**
     * @notice Unfreeze the specified account's frozen tokens if available
     * @param index Index of the frozen tokens record to be unfrozen
     */
    function unfreezeTokens(Vault vault, uint256 index)
        external
        onlyVaultOwner(vault)
    {
        FrozenTokens[] storage userFrozenTokens = frozenTokens[address(vault)];
        require(index < userFrozenTokens.length, "Invalid index specified");

        FrozenTokens memory frozenToken = userFrozenTokens[index];
        require(
            frozenToken.unlockedAt <= now,
            "Unable to unfreeze frozen tokens"
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
     * @notice Fetch the total number of frozen tokens of the specified account
     * @param account Address of the account to be queried
     */
    function getFrozenTokens(address account) public view returns (uint256) {
        FrozenTokens[] memory userFrozenTokens = frozenTokens[account];
        uint256 totalFrozen = 0;
        for (uint256 i = 0; i < userFrozenTokens.length; i++) {
            if (userFrozenTokens[i].unlockedAt > now) {
                totalFrozen = totalFrozen.add(userFrozenTokens[i].amount);
            }
        }
        return totalFrozen;
    }

    // Checkpoints to make sure the account has enough unfrozen tokens
    function _checkAvailableTokens(address account, uint256 amount)
        internal
        view
    {
        // Verify if the user has sufficient unfrozen tokens
        require(
            balanceOf(account).sub(getFrozenTokens(account)) >= amount,
            "Insufficient unfrozen tokens"
        );
    }

    // Override ERC20's `transfer` to include checkpoint for preventing frozenTokens from being transferred
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _checkAvailableTokens(msg.sender, amount);
        // Call internal `_transfer` since we can't pass identical `msg.sender` into ERC20's `transfer` method
        _transfer(msg.sender, recipient, amount);
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
        return true;
    }

    // Custom transfer method to allow vault owners to transfer unfrozen (and unlocked) tokens regardless of allowance
    function transferFromVault(
        Vault vault,
        address recipient,
        uint256 amount
    ) external onlyVaultOwner(vault) {
        _checkAvailableTokens(address(vault), amount);
        _transfer(address(vault), recipient, amount);
    }
}
