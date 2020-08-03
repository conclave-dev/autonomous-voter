// contracts/Bank.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/StandaloneERC20.sol";
import "./Archive.sol";

/**
 * @title VM contract to manage token related functionalities
 *
 */
contract Bank is Ownable, StandaloneERC20 {
    using SafeMath for uint256;

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
        // Set the epoch for the first cycle to be after 7 epochs from now
        initialCycleEpoch = archive.getEpochNumber().add(7);
    }

    // Placeholder method to allow minting tokens to those contributing
    function seed() external payable {
        require(msg.value > 0, "Invalid amount");
        // Currently set to mint on 1:1 basis
        _mint(msg.sender, msg.value);
    }

    function lock(uint256 amount) external {
        LockedToken storage lockedToken = lockedTokens[msg.sender];
        uint256 lockedCycle = lockedToken.lockedCycle;
        require(
            getAccountUnlockedBalance(msg.sender) >= amount,
            "Insufficient unlocked tokens"
        );

        // Set the token to be locked during the next cycle for new locked tokens
        // Otherwise use the existing cycle and update the locked amount
        if (lockedCycle == 0) {
            lockedToken.amount = amount;
            lockedToken.lockedCycle = _getCurrentCycle().add(1);
        } else {
            require(
                lockedCycle > _getCurrentCycle(),
                "Cannot lock additional tokens"
            );
            lockedToken.amount = lockedToken.amount.add(amount);
        }
    }

    function unlock() external {
        LockedToken memory lockedToken = lockedTokens[msg.sender];
        require(lockedToken.amount > 0, "No locked token found");
        require(
            _getCurrentCycle() > lockedToken.lockedCycle,
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

    function getAccountUnlockedBalance(address account)
        public
        view
        returns (uint256)
    {
        return balanceOf(account).sub(lockedTokens[account].amount);
    }

    function _epochToCycle(uint256 epoch) internal view returns (uint256) {
        // Currently, a cycle is completed every 7 epochs, with cycle starts from 1
        require(epoch >= initialCycleEpoch, "Invalid epoch specified");
        return (epoch.sub(initialCycleEpoch)).div(7).add(1);
    }

    function _getCurrentCycle() internal view returns (uint256) {
        return _epochToCycle(archive.getEpochNumber());
    }
}
