pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./Manager.sol";

contract VoteManager is Manager {
    function vote(
        Vault vault,
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes
    ) public onlyOwner onlyManagedVault(address(vault)) {
        vault.vote(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes
        );
    }

    function revokeActive(
        Vault vault,
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) public onlyOwner onlyManagedVault(address(vault)) {
        // Validates group and revoke amount (cannot be zero or greater than pending votes)
        vault.revokeActive(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );
    }

    function revokePending(
        Vault vault,
        address group,
        uint256 amount,
        address adjacentGroupWithLessVotes,
        address adjacentGroupWithMoreVotes,
        uint256 accountGroupIndex
    ) public onlyOwner onlyManagedVault(address(vault)) {
        // Validates group and revoke amount (cannot be zero or greater than pending votes)
        vault.revokePending(
            group,
            amount,
            adjacentGroupWithLessVotes,
            adjacentGroupWithMoreVotes,
            accountGroupIndex
        );
    }
}
