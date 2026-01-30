// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function invoke(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant INVOKE = IInvoke.invoke.selector;

interface IInvoke {
    function invoke(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Invoke is IInvoke, Command {
    uint internal immutable invokeEid = toEid(INVOKE);

    constructor(string memory params) {
        emit Endpoint(nodeId, invokeEid, 0, ABI, params);
    }

    function invoke(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
