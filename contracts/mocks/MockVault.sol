pragma solidity ^0.5.8;

import "celo-monorepo/packages/protocol/contracts/common/interfaces/IAccounts.sol";
import "../Vault.sol";
import "../celo/governance/interfaces/ILockedGold.sol";

contract MockVault is Vault {
    mapping (string => address) private mockContracts;

    function() external payable { }

    function setMockContract(address _address, string calldata name) external {
        mockContracts[name] = _address;
    }

    function getLockedGold() internal view returns (ILockedGold) {
        if (mockContracts["LockedGold"] == address(0)) {
            return ILockedGold(super.getLockedGold());
        }

        return ILockedGold(mockContracts["LockedGold"]);
    }
}
