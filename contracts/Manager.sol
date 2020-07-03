pragma solidity ^0.5.8;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./Archive.sol";
import "./Vault.sol";

contract Manager is Ownable {
    using SafeMath for uint256;

    Archive public archive;

    address public proxyAdmin;
    uint256 public commission;
    uint256 public minimumBalanceRequirement;

    modifier onlyVault() {
        // Confirm that Vault is in the AV network (i.e. stored within the Archive contract)
        require(
            archive.hasVault(Vault(msg.sender).owner(), msg.sender),
            "Invalid vault"
        );
        _;
    }

    modifier onlyManagedVault(address vault) {
        require(
            archive.isManagedVault(vault, address(this)),
            "Unmanaged vault"
        );
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
        _setMinimumBalanceRequirement(minimumRequirement);

        archive = archive_;
        proxyAdmin = admin;
    }

    function setProxyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Invalid admin address");
        proxyAdmin = admin;
    }

    function setCommission(uint256 commission_) external onlyOwner {
        _setCommission(commission_);
    }

    function _setCommission(uint256 commission_) internal {
        require(commission_ >= 1 && commission_ <= 100, "Invalid commission");

        commission = commission_;
    }

    function setMinimumBalanceRequirement(uint256 minimumBalanceRequirement_)
        external
        onlyOwner
    {
        _setMinimumBalanceRequirement(minimumBalanceRequirement_);
    }

    function _setMinimumBalanceRequirement(uint256 minimumBalanceRequirement_)
        internal
    {
        require(
            minimumBalanceRequirement_ > 0,
            "Invalid minimum balance requirement"
        );
        minimumBalanceRequirement = minimumBalanceRequirement_;
    }
}
