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

    function setElection(address mockElection) public {
        contracts[ELECTION_REGISTRY_ID] = mockElection;
        election = mockElection;
    }

    function setAccounts(address mockAccounts) public {
        contracts[ACCOUNTS_REGISTRY_ID] = mockAccounts;
        accounts = mockAccounts;
    }

    function setLockedGold(address mockLockedGold) public {
        contracts[LOCKED_GOLD_REGISTRY_ID] = mockLockedGold;
        lockedGold = mockLockedGold;
    }

    function getAddressForOrDie(bytes32 contractName)
        external
        view
        returns (address)
    {
        return contracts[contractName];
    }
}
