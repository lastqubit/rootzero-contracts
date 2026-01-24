// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function utilize(uint account, uint id, uint amount, bytes data, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = IUtilize.utilize.selector;

interface IUtilize {
    function utilize(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Utilize is IUtilize, Command {
    uint internal immutable utilizeId = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, utilizeId, 0, ABI, params);
    }

    function utilize(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
