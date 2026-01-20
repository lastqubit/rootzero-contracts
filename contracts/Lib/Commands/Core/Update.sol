// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function update(uint account, bytes step) external payable returns (bytes32, bytes)";
bytes4 constant SELECTOR = IUpdate.update.selector;

interface IUpdate {
    function update(
        uint account,
        bytes calldata step
    ) external payable returns (bytes32, bytes memory);
}

abstract contract Update is IUpdate, Command {
    uint internal immutable updateId = toEid(false, SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, updateId, 0, ABI, params);
    }

    function update(
        uint account,
        bytes calldata step
    ) external payable virtual returns (bytes32, bytes memory);
}
