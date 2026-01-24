// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function relay(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = IRelay.relay.selector;

interface IRelay {
    function relay(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Relay is IRelay, Command {
    uint internal immutable relayId = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, relayId, 0, ABI, params);
    }

    function relay(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
