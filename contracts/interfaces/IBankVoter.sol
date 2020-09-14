pragma solidity ^0.5.8;

import "../celo/governance/interfaces/IElection.sol";
import "./IElectionDataProvider.sol";

interface IBankVoter {
    function revoke(
        IElectionDataProvider electionDataProvider,
        uint256 amount,
        address group
    ) external returns (uint256);
}
