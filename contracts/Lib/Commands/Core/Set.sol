// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function set(uint account, bytes step) external payable returns (bytes32, bytes)";
bytes4 constant SELECTOR = ISet.set.selector;

interface ISet {
    function set(uint account, bytes calldata step) external payable returns (bytes32, bytes memory);
}

abstract contract Set is ISet, Command {
    uint internal immutable setId = toEid(false, SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, setId, 0, ABI, params);
    }

    function set(uint account, bytes calldata step) external payable virtual returns (bytes32, bytes memory);
}
