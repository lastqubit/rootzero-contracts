// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command, IProcess, PROCESS} from "../Base.sol";

string constant ABI = "function process(uint account, bytes data, bytes step) external payable returns (bytes4, bytes)";

abstract contract Process is IProcess, Command {
    uint internal immutable processId = toEid(PROCESS);

    constructor(string memory params) {
        emit Endpoint(hostId, processId, 0, ABI, params);
    }

    function process(
        uint account,
        bytes calldata data,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
