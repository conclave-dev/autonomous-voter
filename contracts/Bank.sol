// contracts/Bank.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/StandaloneERC20.sol";

/**
 * @title VM contract to manage token related functionalities
 *
 */
contract Bank is Ownable, StandaloneERC20 {
    using SafeMath for uint256;

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
        address[] memory pausers
    ) public initializer {
        Ownable.initialize(msg.sender);
        StandaloneERC20.initialize(name_, symbol_, decimals_, minters, pausers);
    }

    // Placeholder method to allow minting tokens to those contributing
    function seed() external payable {
        require(msg.value > 0, "Invalid amount");
        // Currently set to mint on 1:1 basis
        _mint(msg.sender, msg.value);
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
