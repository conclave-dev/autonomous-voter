// contracts/interfaces/IVault.sol
pragma solidity ^0.5.8;


interface IVault {
    function deposit() external payable;

    function updateVaultAdmin(address admin) external;
}
