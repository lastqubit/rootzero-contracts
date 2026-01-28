// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function transfer(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = ITransfer.transfer.selector;

interface ITransfer {
    function transfer(
        uint account,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Transfer is ITransfer, Command {
    uint internal immutable actId = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, actId, 0, ABI, params);
    }

    function transfer(
        uint account,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
