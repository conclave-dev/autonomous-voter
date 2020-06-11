// contracts/interfaces/IArchive.sol
pragma solidity ^0.5.8;


interface IArchive {
    function getVault(address owner) external view returns (address);

    function getStrategy(address owner) external view returns (address);

    function setVault(address vault, address owner) external;

    function setStrategy(address strategy, address owner) external;
}
