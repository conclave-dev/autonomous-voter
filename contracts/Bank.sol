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
    uint256 constant seedCapacity = 1000;
    // # of minted AV tokens per CELO
    uint256 constant seedRatio = 1;

    // Seconds AV tokens are frozen post-mint
    // NOTE: Only modifiable seed parameter
    uint256 seedFreezeDuration;

    struct LockedToken {
        uint256 amount;
        uint256 cycle;
    }

    mapping(address => LockedToken) internal lockedTokens;

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
    function seed(Vault vault) external payable {
        require(msg.sender == vault.owner(), "Must be vault owner");
        require(msg.value > 0, "Invalid amount");

        // Currently set to mint on 1:1 basis
        _mint(msg.sender, msg.value);

        // TODO: Store the minted amount + lockup (worked on by EM)
    }

    // Locks an account's token balance by adding it to `lockedTokens`
    function lock(address account, uint256 cycle) external {
        lockedTokens[account] = LockedToken(balanceOf(account), cycle);
    }

    // Unlocks an account's token balance by deleting it from `lockedTokens`
    function unlock(address account) external {
        delete lockedTokens[account];
    }
}
