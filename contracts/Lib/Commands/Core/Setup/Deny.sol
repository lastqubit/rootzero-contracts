// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function deny(uint account, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant DENY = IDeny.deny.selector;

interface IDeny {
    function deny(uint account, bytes calldata step) external payable returns (bytes4, bytes memory);
}

abstract contract Deny is IDeny, Command {
    uint internal immutable denyEid = toEid(DENY);

    constructor(string memory params) {
        emit Endpoint(nodeId, denyEid, 0, ABI, params);
    }

    function deny(uint account, bytes calldata step) external payable virtual returns (bytes4, bytes memory);
}
