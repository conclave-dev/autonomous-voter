// contracts/Bank.sol
pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/StandaloneERC20.sol";

/**
 * @title VM contract to manage token related functionalities
 *
 */
contract Bank is StandaloneERC20 {
    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address[] memory minters,
        address[] memory pausers
    ) public initializer {
        StandaloneERC20.initialize(name, symbol, decimals, minters, pausers);
    }
}
