pragma solidity ^0.5.8;

import "celo-monorepo/packages/protocol/contracts/governance/interfaces/ILockedGold.sol";

contract MockLockedGold {
    function lock() external payable {}
}
