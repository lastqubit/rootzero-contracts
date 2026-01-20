// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../Base.sol";

string constant ABI = "function transform(uint account, uint id, uint amount, bytes data, bytes step) external payable returns (bytes32, bytes)";
bytes4 constant SELECTOR = ITransform.transform.selector;

interface ITransform {
    function transform(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes32, bytes memory);
}

abstract contract Transform is ITransform, Command {
    uint internal immutable transformId = toEid(false, SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, transformId, 0, ABI, params);
    }

    function transform(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable virtual returns (bytes32, bytes memory);
}
