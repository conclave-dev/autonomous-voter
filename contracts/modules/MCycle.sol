// contracts/Voting.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

contract MCycle {
    using SafeMath for uint256;

    // Block number which protocol will be enabled
    // NOTE: First cycle = genesisBlockNumber + blockDuration
    // This allows users to submit and upvote on allocations
    uint256 public genesisBlockNumber;

    // Duration (in blocks) of a cycle
    uint256 public blockDuration;

    function _setCycleParameters(uint256 genesis, uint256 duration) internal {
        require(genesis >= block.number, "Genesis must be a future block");
        require(duration != 0, "Duration cannot be 0 blocks");

        genesisBlockNumber = genesis;
        blockDuration = duration;
    }

    // Gets the current cycle # by comparing the current block # with the parameters
    // NOTE: The return value is rounded down
    function getCycle() public view returns (uint256) {
        require(block.number < genesisBlockNumber, "Protocol has not started");
        require(
            genesisBlockNumber != 0 && blockDuration != 0,
            "Parameters not set"
        );

        uint256 elapsedBlocks = block.number.sub(genesisBlockNumber);

        return elapsedBlocks.div(blockDuration);
    }
}
