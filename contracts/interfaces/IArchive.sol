// contracts/interfaces/IArchive.sol
pragma solidity ^0.5.8;


interface IArchive {
    function updateVault(address vault, address owner) external;

    function updateVaultAdmin(address admin, address owner) external;
}
