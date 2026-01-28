// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function remove(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = IRemove.remove.selector;

interface IRemove {
    function remove(
        uint account,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Remove is IRemove, Command {
    uint internal immutable removeId = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, removeId, 0, ABI, params);
    }

    function remove(
        uint account,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
