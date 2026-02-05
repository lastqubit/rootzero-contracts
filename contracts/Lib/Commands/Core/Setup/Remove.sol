// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

bytes4 constant REMOVE = IRemove.remove.selector;

interface IRemove {
    function remove(
        uint account,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Remove is IRemove, Command {
    uint internal immutable removeId = toEid(REMOVE);

    constructor(string memory params) {
        emit Step(nodeId, removeId, 0, REMOVE, params);
    }

    function remove(
        uint account,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
