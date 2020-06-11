// contracts/interfaces/IArchive.sol
pragma solidity ^0.5.8;


interface IArchive {
    function getVaultOwner(address owner_) external view returns (address);

    function getVaultManagerOwner(address owner_) external view returns (address);

    function associateVaultWithOwner(address vault, address owner_) external;

    function associateVaultManagerWithOwner(address vaultManager, address owner_) external;
}
