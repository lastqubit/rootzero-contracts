// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

contract TestExecuteTarget {
    event Ping(address caller, uint value, uint amount, bytes data);

    error CallFailed(bytes reason);

    function ping(uint amount, bytes calldata data) external payable {
        emit Ping(msg.sender, msg.value, amount, data);
    }

    function number() external pure returns (uint) {
        return 42;
    }

    function callTarget(address target, bytes calldata data) external payable returns (bytes memory result) {
        bool success;
        (success, result) = target.call{value: msg.value}(data);
        if (!success) revert CallFailed(result);
    }
}
