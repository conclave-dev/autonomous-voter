pragma solidity ^0.5.8;

import "celo-monorepo/packages/protocol/contracts/common/interfaces/IAccounts.sol";

contract MockAccounts {
    function createAccount() external returns (bool) {
        return true;
    }
}
