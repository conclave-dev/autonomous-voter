// contracts/Governance.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "../celo/governance/interfaces/IGovernance.sol";

contract Governance is Ownable {
    IGovernance public governance;

    function initializeGovernance(IGovernance governance_) public initializer {
        governance = governance_;
    }

    function vote(
        uint256 proposalId,
        uint256 index,
        uint8 value
    ) external returns (bool) {
        governance.vote(proposalId, index, value);
    }
}
