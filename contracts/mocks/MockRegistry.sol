pragma solidity ^0.5.8;

contract MockRegistry {
    mapping(bytes32 => address) public contracts;

    // To prevent re-setting contracts unnecessarily
    address public election;
    address public accounts;
    address public lockedGold;

    bytes32 constant ELECTION_REGISTRY_ID = keccak256(
        abi.encodePacked("Election")
    );

    bytes32 constant ACCOUNTS_REGISTRY_ID = keccak256(
        abi.encodePacked("Accounts")
    );

    bytes32 constant LOCKED_GOLD_REGISTRY_ID = keccak256(
        abi.encodePacked("LockedGold")
    );

    function setElection(address election_) public {
        contracts[ELECTION_REGISTRY_ID] = election_;
        election = election_;
    }

    function setAccounts(address accounts_) public {
        contracts[ACCOUNTS_REGISTRY_ID] = accounts_;
        accounts = accounts_;
    }

    function setLockedGold(address lockedGold_) public {
        contracts[LOCKED_GOLD_REGISTRY_ID] = lockedGold_;
        lockedGold = lockedGold_;
    }

    function getAddressForOrDie(bytes32 contractName)
        external
        view
        returns (address)
    {
        return contracts[contractName];
    }
}
