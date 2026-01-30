// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command, ISetup, SETUP} from "../Base.sol";

string constant ABI = "function setup(uint account, bytes step) external payable returns (bytes4, bytes)";

abstract contract Setup is ISetup, Command {
    uint internal immutable setupId = toEid(SETUP);

    constructor(string memory params) {
        emit Endpoint(nodeId, setupId, 0, ABI, params);
    }

    function setup(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
