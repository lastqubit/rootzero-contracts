// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.33;

import {Command} from "../../Base.sol";

string constant ABI = "function publish(uint account, uint id, uint amount, bytes data, bytes step) external payable returns (bytes4, bytes)";
bytes4 constant SELECTOR = IPublish.publish.selector;

interface IPublish {
    function publish(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable returns (bytes4, bytes memory);
}

abstract contract Publish is IPublish, Command {
    uint internal immutable publishEid = toEid(SELECTOR);

    constructor(string memory params) {
        emit Endpoint(hostId, publishEid, 0, ABI, params);
    }

    function publish(
        uint account,
        uint id,
        uint amount,
        bytes calldata data,
        bytes calldata step
    ) external payable virtual returns (bytes4, bytes memory);
}
