// contracts/interfaces/IArchive.sol
pragma solidity ^0.5.8;


interface IArchive {
    function getVault(address owner) external view returns (address);

    function getStrategy(address owner) external view returns (address);

    function updateVault(address vault, address owner) external;

    function updateStrategy(address strategy, address owner) external;
}
