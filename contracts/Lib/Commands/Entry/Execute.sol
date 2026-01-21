// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function execute(bytes[] steps, bytes signed) external payable returns(uint count)";
bytes4 constant SELECTOR = IExecute.execute.selector;

interface IExecute {
    function execute(bytes[] calldata steps, bytes calldata signed) external payable returns (uint);
}

abstract contract Execute is IExecute, Command {
    constructor() {
        emit Endpoint(hostId, toEid(false, SELECTOR), 0, ABI, "");
    }

    function execute(bytes[] calldata steps, bytes calldata signed) external payable virtual returns (uint);
}
