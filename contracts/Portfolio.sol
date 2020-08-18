// contracts/Voting.sol
pragma solidity ^0.5.8;

import "./modules/MVoting.sol";
import "./celo/common/UsingRegistry.sol";
import "./celo/common/libraries/AddressLinkedList.sol";
import "./Vault.sol";

contract Portfolio is MVoting, UsingRegistry {
    using AddressLinkedList for LinkedList.List;

    LinkedList.List public vaults;

    function initialize(address registry_, uint256 max)
        public
        payable
        initializer
    {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
        Ownable.initialize(msg.sender);

        // Set Voting module parameters
        _setElection(getElection());
        _setGroupMaximum(max);
    }

    function manageVault(Vault vault) external {
        require(msg.sender == vault.owner(), "Sender is not vault owner");
        vaults.push(address(vault));
    }
}
