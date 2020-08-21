// contracts/Voting.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

contract MVotes {
    using SafeMath for uint256;

    struct Group {
        // Index of an eligible Celo election group
        uint256 index;
        // Percentage of the total votes
        uint256 allocation;
        // # of votes received
        uint256 received;
    }

    struct Votes {
        uint256 total;
        // # of votes placed
        uint256 placed;
    }

    address public manager;
    Group[] public voteAllocations;

    /**
     * @notice Sets the voting manager
     * @param manager_ Manager address
     */
    function _setManager(address manager_) internal {
        manager = manager_;
    }
}
