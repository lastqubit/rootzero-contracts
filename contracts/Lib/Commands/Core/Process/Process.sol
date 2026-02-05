// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command, IProcess, PROCESS} from "../Base.sol";

abstract contract Process is IProcess, Command {
    uint internal immutable processId = toEid(PROCESS);

    constructor(string memory params) {
        emit Step(nodeId, processId, 0, PROCESS, params);
    }

    function process(
        uint account,
        bytes calldata data,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
