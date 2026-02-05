// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

bytes4 constant APPROVE = IApprove.approve.selector;

interface IApprove {
    function approve(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Approve is IApprove, Command {
    uint internal immutable approveId = toEid(APPROVE);

    constructor(string memory params) {
        emit Step(nodeId, approveId, 0, APPROVE, params);
    }

    function approve(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
