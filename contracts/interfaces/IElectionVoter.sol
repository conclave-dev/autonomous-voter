pragma solidity ^0.5.8;

import "../celo/governance/interfaces/IElection.sol";
import "./IElectionDataProvider.sol";

interface IElectionVoter {
    function revoke(
        IElection election,
        IElectionDataProvider electionDataProvider,
        uint256 amount,
        address group
    ) external returns (uint256);
}
