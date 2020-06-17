// contracts/VaultManager.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./VaultManager.sol";
import "./Vault.sol";

contract VotingVaultManager is VaultManager {
    function initialize(
        Archive archive_,
        address owner_,
        address admin,
        uint256 sharePercentage,
        uint256 minimumRequirement
    ) public initializer {
        VaultManager.initialize(
            archive_,
            owner_,
            admin,
            sharePercentage,
            minimumRequirement
        );
        Ownable.initialize(owner_);
    }

    function vote(
        address vault,
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes
    ) public onlyOwner {
        Vault(vault).vote(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes
        );
    }
}
