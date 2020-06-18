// contracts/VotingVaultManagerFactory.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "./App.sol";
import "./Archive.sol";
import "./VaultManagerFactory.sol";

contract VotingVaultManagerFactory is VaultManagerFactory {
    function initialize(
        App app_,
        Archive archive_,
        string memory contractName_
    ) public initializer {
        VaultManagerFactory.initialize(app_, archive_, contractName_);
    }

    function createInstance(uint256 sharePercentage, uint256 minimumGold)
        public
        payable
    {
        VaultManagerFactory.createInstance(sharePercentage, minimumGold);
    }
}
