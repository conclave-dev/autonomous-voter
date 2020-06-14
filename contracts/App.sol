pragma solidity ^0.5.8;

import "@openzeppelin/upgrades/contracts/upgradeability/AdminUpgradeabilityProxy.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";

/**
 * @title App
 * @dev Contract for upgradeable applications.
 * It handles the creation of proxies.
 */
contract App is Initializable, Ownable {
    mapping(string => address) public contractImplementations;
    mapping(string => address) public contractFactories;

    function initialize() public initializer {
        Ownable.initialize(msg.sender);
    }

    /**
     * @dev Update the implementation address for the specified contractName
     * @param contractName Name of the contract to be updated.
     * @param implementation Address of the contract implementation to be used.
     */
    function setContractImplementation(
        string memory contractName,
        address implementation
    ) public onlyOwner {
        require(implementation != address(0), "Invalid implementation address");
        contractImplementations[contractName] = implementation;
    }

    /**
     * @dev Update the factory address for the specified contractName
     * @param contractName Name of the contract to be updated.
     * @param factory Address of the factory contract responsible to create new contract instances.
     */
    function setContractFactory(string memory contractName, address factory)
        public
        onlyOwner
    {
        require(factory != address(0), "Invalid factory address");
        contractFactories[contractName] = factory;
    }

    /**
     * @dev Creates a new proxy for the given contract and forwards a function call to it.
     * This is useful to initialize the proxied contract.
     * @param contractName Name of the contract used as an identifier.
     * @param admin Address of the proxy administrator.
     * @param data Data to send as msg.data to the corresponding implementation to initialize the proxied contract.
     * It should include the signature and the parameters of the function to be called, as described in
     * https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding.
     * This parameter is optional, if no data is given the initialization call to proxied contract will be skipped.
     * @return Address of the new proxy.
     */
    function create(
        string memory contractName,
        address admin,
        bytes memory data
    ) public payable returns (AdminUpgradeabilityProxy) {
        require(
            msg.sender == contractFactories[contractName],
            "Invalid factory contract"
        );
        address implementation = contractImplementations[contractName];
        require(implementation != address(0), "Implementation not found");

        AdminUpgradeabilityProxy proxy = (new AdminUpgradeabilityProxy).value(
            msg.value
        )(implementation, admin, data);

        return proxy;
    }
}
