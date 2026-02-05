// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

bytes4 constant EXECUTE = IExecute.execute.selector;

interface IExecute {
    function execute(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Execute is IExecute, Command {
    uint internal immutable executeId = toEid(EXECUTE);

    constructor(string memory params) {
        emit Step(nodeId, executeId, 0, EXECUTE, params);
    }

    function execute(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
