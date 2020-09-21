pragma solidity ^0.5.8;

interface IBank {
    function balanceOf(address) external view returns (uint256);
}
