// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function act(uint account, bytes step) external payable returns (bytes32, bytes)";
bytes4 constant SELECTOR = IAct.act.selector;

interface IAct {
    function act(uint account, bytes calldata step) external payable returns (bytes32, bytes memory);
}

abstract contract Act is IAct, Command {
    uint internal immutable actId = toEid(false, SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, actId, 0, ABI, params);
    }

    function act(uint account, bytes calldata step) external payable virtual returns (bytes32, bytes memory);
}
