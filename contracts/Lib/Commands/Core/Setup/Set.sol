// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

bytes4 constant SET = ISet.set.selector;

interface ISet {
    function set(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Set is ISet, Command {
    uint internal immutable setId = toEid(SET);

    constructor(string memory params) {
        emit Step(nodeId, setId, 0, SET, params);
    }

    function set(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
