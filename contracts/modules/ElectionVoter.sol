// contracts/Voting.sol
pragma solidity ^0.5.8;

import "../celo/common/libraries/AddressLinkedList.sol";
import "./ElectionManager.sol";

contract ElectionVoter {
    ElectionManager electionManager;

    /**
     * @notice Sets the ElectionManager contract, allowing it to manage votes
     * @param electionManager_ Contract address
     */
    function _setElectionManager(address electionManager_) internal {
        electionManager = ElectionManager(electionManager_);
        electionManager.addVoter();
    }
}
