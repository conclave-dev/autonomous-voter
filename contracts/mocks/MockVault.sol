pragma solidity ^0.5.8;

import "celo-monorepo/packages/protocol/contracts/common/interfaces/IAccounts.sol";
import "../Vault.sol";
import "../celo/governance/interfaces/ILockedGold.sol";

contract MockVault is Vault {
    function() external payable {}

    function setMockLockedGold(address _address) external {
        lockedGold = ILockedGold(_address);
    }
}
