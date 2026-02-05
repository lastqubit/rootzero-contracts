// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

bytes4 constant TRANSFORM = ITransform.transform.selector;

interface ITransform {
    function transform(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Transform is ITransform, Command {
    uint internal immutable transformId = toEid(TRANSFORM);

    constructor(string memory params) {
        emit Step(nodeId, transformId, 0, TRANSFORM, params);
    }

    function transform(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
