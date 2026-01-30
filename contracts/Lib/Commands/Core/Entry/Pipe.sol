// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function pipe(uint192 deadline, bytes[] steps, bytes signed) external payable returns(uint count)";
bytes4 constant SELECTOR = IPipe.pipe.selector;

interface IPipe {
    function pipe(uint192 deadline, bytes[] calldata steps, bytes calldata signed) external payable returns (uint);
}

abstract contract Pipe is IPipe, Command {
    uint internal immutable pipeId = toEid(SELECTOR);

    constructor() {
        emit Endpoint(nodeId, pipeId, 0, ABI, "");
    }

    function pipe(
        uint192 deadline,
        bytes[] calldata steps,
        bytes calldata signed
    ) external payable virtual returns (uint);
}
