// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

bytes4 constant UPDATE = IUpdate.update.selector;

interface IUpdate {
    function update(
        uint account,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Update is IUpdate, Command {
    uint internal immutable updateId = toEid(UPDATE);

    constructor(string memory params) {
        emit Step(nodeId, updateId, 0, UPDATE, params);
    }

    function update(
        uint account,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
