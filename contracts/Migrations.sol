pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";


contract Migrations is Ownable {
    uint256 public last_completed_migration;

    modifier restricted() {
        if (msg.sender == owner()) _;
    }

    function initialize() public initializer {
        Ownable.initialize(msg.sender);
    }

    function setCompleted(uint256 completed) public restricted {
        last_completed_migration = completed;
    }

    function upgrade(address new_address) public restricted {
        Migrations upgraded = Migrations(new_address);
        upgraded.setCompleted(last_completed_migration);
    }
}
