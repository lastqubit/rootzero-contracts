// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function allow(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant ALLOW = IAllow.allow.selector;

interface IAllow {
    function allow(
        uint account,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Allow is IAllow, Command {
    uint internal immutable allowEid = toEid(ALLOW);

    constructor(string memory params) {
        emit Endpoint(nodeId, allowEid, 0, ABI, params);
    }

    function allow(
        uint account,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
