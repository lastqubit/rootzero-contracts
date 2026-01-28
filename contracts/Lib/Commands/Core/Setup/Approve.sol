// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function approve(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = IApprove.approve.selector;

interface IApprove {
    function approve(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Approve is IApprove, Command {
    uint internal immutable approveId = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, approveId, 0, ABI, params);
    }

    function approve(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
