// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function create(uint account, bytes step) external payable returns (bytes32, bytes)";
bytes4 constant SELECTOR = ICreate.create.selector;

interface ICreate {
    function create(uint account, bytes calldata step) external payable returns (bytes32, bytes memory);
}

abstract contract Create is ICreate, Command {
    uint internal immutable createId = toEid(false, SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, createId, 0, ABI, params);
    }

    function create(uint account, bytes calldata step) external payable virtual returns (bytes32, bytes memory);
}
