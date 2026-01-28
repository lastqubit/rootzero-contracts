// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function execute(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = IExecute.execute.selector;

interface IExecute {
    function execute(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Execute is IExecute, Command {
    uint internal immutable executeId = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, executeId, 0, ABI, params);
    }

    function execute(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
