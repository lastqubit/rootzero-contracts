// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function collect(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = ICollect.collect.selector;

interface ICollect {
    function collect(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Collect is ICollect, Command {
    uint internal immutable collectId = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, collectId, 0, ABI, params);
    }

    function collect(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
