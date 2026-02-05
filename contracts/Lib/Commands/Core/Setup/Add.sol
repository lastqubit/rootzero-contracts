// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

bytes4 constant ADD = IAdd.add.selector;

interface IAdd {
    function add(
        uint account,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Add is IAdd, Command {
    uint internal immutable addId = toEid(ADD);

    constructor(string memory params) {
        emit Step(nodeId, addId, 0, ADD, params);
    }

    function add(
        uint account,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
