// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

contract TestExecuteTarget {
    event Ping(address caller, uint value, uint amount, bytes data);

    function ping(uint amount, bytes calldata data) external payable {
        emit Ping(msg.sender, msg.value, amount, data);
    }
}
