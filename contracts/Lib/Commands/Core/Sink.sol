// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function sink(uint account, uint id, uint amount, bytes data, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = ISink.sink.selector;

interface ISink {
    function sink(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}


abstract contract Sink is ISink, Command {
    uint internal immutable sinkEid = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, sinkEid, 0, ABI, params);
    }

    function sink(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
