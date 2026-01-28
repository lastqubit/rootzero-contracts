// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function relay(uint account, uint id, uint amount, bytes data, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant RELAY = IRelay.relay.selector;

interface IRelay {
    function relay(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Relay is IRelay, Command {
    uint internal immutable relayId = toEid(RELAY);

    constructor(string memory params) {
        emit Endpoint(hostId, relayId, 0, ABI, params);
    }

    function relay(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
