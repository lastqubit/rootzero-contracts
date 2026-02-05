// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

bytes4 constant CREATE = ICreate.create.selector;

interface ICreate {
    function create(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Create is ICreate, Command {
    uint internal immutable createId = toEid(CREATE);

    constructor(string memory params) {
        emit Step(nodeId, createId, 0, CREATE, params);
    }

    function create(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
