// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function push(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = IPush.push.selector;

/* Push-based operations:

repay → push (push back to pool)
deposit → push (push into vault)
contribute → push (push funds) */

interface IPush {
    function push(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Push is IPush, Command {
    uint internal immutable pushId = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, pushId, 0, ABI, params);
    }

    function push(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
