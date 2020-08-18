// contracts/Voting.sol
pragma solidity ^0.5.8;

import "./modules/MVoting.sol";
import "./celo/common/UsingRegistry.sol";
import "./celo/common/libraries/AddressLinkedList.sol";

contract Portfolio is MVoting, UsingRegistry {
    function initialize(address registry_, uint256 maxGroups_)
        public
        payable
        initializer
    {
        UsingRegistry.initializeRegistry(msg.sender, registry_);
        Ownable.initialize(msg.sender);

        // Set Voting module parameters
        _setElection(getElection());
        _setMaxGroups(maxGroups_);
    }
}
