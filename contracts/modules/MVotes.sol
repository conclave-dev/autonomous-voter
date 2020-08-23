// contracts/Voting.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

contract MVotes {
    using SafeMath for uint256;

    // High-level details about the votes managed by the protocol
    struct Votes {
        uint256 total;
        // Number of votes that have been placed overall
        uint256 voted;
    }

    // Details about a group that will receive votes
    struct Group {
        // Index of the eligible Celo election group
        uint256 groupIndex;
        // Percent of total votes allocated to the group
        uint256 percentOfTotal;
        // Number of votes that have been placed for the group
        uint256 voted;
    }

    Votes public votes;
    mapping(uint256 => Group[]) groupsByCycle;
}
