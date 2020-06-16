pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract MockLockedGold {
    using SafeMath for uint256;

    struct PendingWithdrawal {
        uint256 amount;
        uint256 timestamp;
    }

    mapping (address => uint256) private balances;
    mapping (address => PendingWithdrawal[]) private withdrawals;

    uint256 private unlockingPeriod;

    function reset() external {
        balances[msg.sender] = 0;
        withdrawals[msg.sender].length = 0;
    }

    function setUnlockingPeriod(uint256 duration) external {
        unlockingPeriod = duration;
    }

    function lock() payable external {
        balances[msg.sender] = balances[msg.sender].add(msg.value);
    }

    function unlock(uint256 amount) external {
        require(amount <= balances[msg.sender], "Invalid amount");
        PendingWithdrawal memory withdrawal = PendingWithdrawal(amount, now.add(unlockingPeriod));
        withdrawals[msg.sender].push(withdrawal);

        balances[msg.sender] = balances[msg.sender].sub(amount);
    }

    function getAccountNonvotingLockedGold(address account) external view returns (uint256) {
        return balances[account];
    }

    function getPendingWithdrawals(address account) external view returns (uint256[] memory, uint256[] memory) {
        uint256 length = withdrawals[account].length;
        uint256[] memory amounts = new uint256[](length);
        uint256[] memory timestamps = new uint256[](length);

        for (uint256 i = 0; i < length; i = i.add(1)) {
            PendingWithdrawal memory pendingWithdrawal = withdrawals[account][i];
            amounts[i] = pendingWithdrawal.amount;
            timestamps[i] = pendingWithdrawal.timestamp;
        }

        return (amounts, timestamps);
    }

    function withdraw(uint256 index) external {
        require(withdrawals[msg.sender].length > index, "Index out-of-bound");
        PendingWithdrawal memory pendingWithdrawal = withdrawals[msg.sender][index];

        require(pendingWithdrawal.timestamp < now, "Withdrawal is not yet available");

        uint256 lastIndex = withdrawals[msg.sender].length.sub(1);
        withdrawals[msg.sender][index] = withdrawals[msg.sender][lastIndex];
        withdrawals[msg.sender].length = lastIndex;

        msg.sender.transfer(pendingWithdrawal.amount);
    }
}
