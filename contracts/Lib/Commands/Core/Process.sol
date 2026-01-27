// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function process(uint account, bytes data, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = IProcess.process.selector;

interface IProcess {
    function process(
        uint account,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Process is IProcess, Command {
    uint internal immutable processEid = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, processEid, 0, ABI, params);
    }

    function process(uint account, bytes calldata data, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
