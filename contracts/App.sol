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
    mapping (string => address) contractImplementations;

    /**
     * @dev Emitted when a new vault proxy is created.
     * @param proxy Address of the created proxy.
     */
    event ProxyCreated(string contractName, address proxy);

    function initialize() public initializer {
        Ownable.initialize(msg.sender);
    }

    /**
     * @dev Update the implementation address for the specified contractName
     * @param contractName Name of the contract to be updated.
     * @param implementation Address of the contract implementation to be used.
     */
    function setImplementation(string memory contractName, address implementation) public onlyOwner {
        require(implementation != address(0), "Invalid implementation address");
        contractImplementations[contractName] = implementation;
    }

    /**
     * @dev Creates a new proxy for the given contract and forwards a function call to it.
     * This is useful to initialize the proxied contract.
     * @param admin Address of the proxy administrator.
     * @param data Data to send as msg.data to the corresponding implementation to initialize the proxied contract.
     * It should include the signature and the parameters of the function to be called, as described in
     * https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding.
     * This parameter is optional, if no data is given the initialization call to proxied contract will be skipped.
     * @return Address of the new proxy.
     */
    function create(string memory contractName, address admin, bytes memory data)
        public
        payable
        returns (AdminUpgradeabilityProxy)
    {
        address implementation = contractImplementations[contractName];
        require(implementation != address(0), "Implementation not found");

        AdminUpgradeabilityProxy proxy = (new AdminUpgradeabilityProxy).value(
            msg.value
        )(implementation, admin, data);
        emit ProxyCreated(contractName, address(proxy));
        return proxy;
    }
}
