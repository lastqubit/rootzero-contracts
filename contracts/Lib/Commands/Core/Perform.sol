// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function perform(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = IPerform.perform.selector;

interface IPerform {
    function perform(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Perform is IPerform, Command {
    uint internal immutable performId = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, performId, 0, ABI, params);
    }

    function perform(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
