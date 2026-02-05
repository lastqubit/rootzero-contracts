// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

bytes4 constant COLLECT = ICollect.collect.selector;

interface ICollect {
    function collect(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Collect is ICollect, Command {
    uint internal immutable collectId = toEid(COLLECT);

    constructor(string memory params) {
        emit Step(nodeId, collectId, 0, COLLECT, params);
    }

    function collect(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
