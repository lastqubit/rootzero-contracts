// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

bytes4 constant ALLOW = IAllow.allow.selector;

interface IAllow {
    function allow(
        uint account,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Allow is IAllow, Command {
    uint internal immutable allowEid = toEid(ALLOW);

    constructor(string memory params) {
        emit Step(nodeId, allowEid, 0, ALLOW, params);
    }

    function allow(
        uint account,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
