// contracts/Voting.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

contract Protocol {
    using SafeMath for uint256;

    // Block number which protocol will be enabled
    // NOTE: First cycle = genesisBlockNumber + blockDuration
    // This allows users to submit and upvote on allocations
    uint256 public genesisBlockNumber;

    // Duration (in blocks) of a cycle
    uint256 public blockDuration;

    /**
     * @notice Gets the current cycle number
     * @return The current cycle number
     */
    function getCurrentCycle() public view returns (uint256) {
        require(
            block.number < genesisBlockNumber,
            "The genesis cycle has not started"
        );
        require(
            genesisBlockNumber != 0 && blockDuration != 0,
            "Parameters have not been set"
        );

        uint256 elapsedBlocks = block.number.sub(genesisBlockNumber);

        return elapsedBlocks.div(blockDuration);
    }
}
