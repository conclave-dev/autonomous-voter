// contracts/Bank.sol
pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";

/**
 * @title VM contract to manage token related functionalities
 *
 */
contract Bank is Initializable, ERC20Detailed, ERC20Pausable {
    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialSupply,
        address[] memory pausers
    ) public initializer {
        ERC20Detailed.initialize(name, symbol, decimals);

        // Mint the entire supply of the tokens to the contract itself as the origin
        _mint(address(this), initialSupply);

        // Initialize the pauser roles, and renounce them
        ERC20Pausable.initialize(address(this));
        _removePauser(address(this));

        // Add the requested pausers (this can be done after renouncing since these are the internal calls)
        for (uint256 i = 0; i < pausers.length; ++i) {
            _addPauser(pausers[i]);
        }
    }
}
