pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Archive.sol";
import "./Vault.sol";
import "./celo/common/libraries/AddressLinkedList.sol";

contract Manager is Ownable {
    using SafeMath for uint256;
    using AddressLinkedList for LinkedList.List;

    Archive public archive;

    address public proxyAdmin;
    uint256 public commission;
    uint256 public minimumBalanceRequirement;

    LinkedList.List public vaults;

    modifier onlyVault() {
        // Confirm that Vault is in the AV network (i.e. stored within the Archive contract)
        require(
            archive.hasVault(Vault(msg.sender).owner(), msg.sender),
            "Invalid vault"
        );
        _;
    }

    modifier onlyManagedVault(address vault) {
        require(vaults.contains(vault) == true, "Unmanaged vault");
        _;
    }

    function initialize(
        Archive archive_,
        address owner_,
        address admin,
        uint256 commission_,
        uint256 minimumRequirement
    ) public initializer {
        Ownable.initialize(owner_);
        _setCommission(commission_);

        archive = archive_;
        proxyAdmin = admin;
        minimumBalanceRequirement = minimumRequirement;
    }

    function setProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function setCommission(uint256 commission_) public onlyOwner {
        _setCommission(commission_);
    }

    function _setCommission(uint256 commission_) internal {
        require(commission_ >= 1 && commission_ <= 100, "Invalid commission");

        commission = commission_;
    }

    function setMinimumBalanceRequirement(uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid amount");
        minimumBalanceRequirement = amount;
    }

    function getVaults() external view returns (address[] memory) {
        return vaults.getKeys();
    }

    function registerVault() external onlyVault {
        require(vaults.contains(msg.sender) == false, "Already registered");

        (uint256 votingBalance, uint256 nonvotingBalance) = Vault(msg.sender)
            .getBalances();

        require(
            votingBalance.add(nonvotingBalance) >= minimumBalanceRequirement,
            "Insufficient manageble balance"
        );

        vaults.push(msg.sender);
    }

    function deregisterVault() external onlyVault {
        require(vaults.contains(msg.sender) == true, "Not registered");

        vaults.remove(msg.sender);
    }
}
