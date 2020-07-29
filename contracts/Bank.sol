// contracts/Bank.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/StandaloneERC20.sol";
import "./Archive.sol";

/**
 * @title VM contract to manage token related functionalities
 *
 */
contract Bank is Ownable, StandaloneERC20 {
    struct LockedToken {
        uint256 amount;
        uint256 lockedCycle;
    }

    Archive public archive;
    uint256 public initialCycleEpoch;
    mapping(address => LockedToken) internal lockedTokens;

    function initialize(
        address archive_,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address[] memory minters,
        address[] memory pausers
    ) public initializer {
        Ownable.initialize(msg.sender);
        StandaloneERC20.initialize(name, symbol, decimals, minters, pausers);
        archive = Archive(archive_);
    }

    // Placeholder method to kickstart the VM service and set the epoch for the first cycle
    function start() external onlyOwner {
        require(initialCycleEpoch == 0, "First cycle epoch has been set");
        initialCycleEpoch = _epochToCycle(archive.getEpochNumber());
    }

    // Placeholder method to allow minting tokens to those contributing
    function contribute() external payable {
        require(msg.value > 0, "Invalid amount");
        // Currently set to mint on 1:1 basis
        _mint(msg.sender, msg.value);
    }

    function lock(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        // Set the token to be locked during the next cycle
        uint256 currentCycle = _epochToCycle(archive.getEpochNumber()) + 1;
        lockedTokens[msg.sender] = LockedToken(amount, currentCycle);
    }

    function unlock() external {
        LockedToken memory lockedToken = lockedTokens[msg.sender];
        require(lockedToken.amount > 0, "No locked token found");
        uint256 currentCycle = _epochToCycle(archive.getEpochNumber());
        require(
            currentCycle > lockedToken.lockedCycle,
            "Tokens can not be unlocked yet"
        );
        delete lockedTokens[msg.sender];
    }

    function getAccountLockedToken(address account)
        external
        view
        returns (uint256, uint256)
    {
        require(account != address(0), "Invalid account");
        LockedToken memory lockedToken = lockedTokens[account];
        return (lockedToken.amount, lockedToken.lockedCycle);
    }

    function _epochToCycle(uint256 epoch) internal pure returns (uint256) {
        // Currently, a cycle is completed every 7 epochs
        return epoch / 7;
    }
}
