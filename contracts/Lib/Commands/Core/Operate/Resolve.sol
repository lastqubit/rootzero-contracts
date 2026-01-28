// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function resolve(uint account, uint id, uint amount, bytes data, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant RESOLVE = IResolve.resolve.selector;

interface IResolve {
    function resolve(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}


abstract contract Resolve is IResolve, Command {
    uint internal immutable resolveId = toEid(RESOLVE);

    constructor(string memory params) {
        emit Endpoint(hostId, resolveId, 0, ABI, params);
    }

    function resolve(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
