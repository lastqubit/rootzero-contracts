// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../../Base.sol";

string constant ABI = "function add(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = IAdd.add.selector;

interface IAdd {
    function add(
        uint account,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Add is IAdd, Command {
    uint internal immutable addId = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, addId, 0, ABI, params);
    }

    function add(
        uint account,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
