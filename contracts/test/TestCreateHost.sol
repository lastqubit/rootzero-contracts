// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Host } from "../core/Host.sol";
import { Create } from "../commands/Create.sol";
import { Cursors, Cur, Keys } from "../Cursors.sol";
import { Ids } from "../utils/Ids.sol";

using Cursors for Cur;

contract TestCreateHost is Host, Create {
    event CreateCalled(bytes32 account, bytes inputData);

    constructor(address cmdr)
        Host(address(0), 1, "test")
        Create("")
    {
        if (cmdr != address(0)) access(Ids.toHost(cmdr), true);
    }

    function create(bytes32 account, Cur memory input) internal override {
        (bytes4 key, uint len) = input.peek(input.i);
        bytes calldata inputData;
        if (key == Keys.Route) {
            inputData = input.unpackRoute();
        } else {
            uint next = input.i + 8 + len;
            inputData = msg.data[input.offset + input.i:input.offset + next];
            input.i = next;
        }
        emit CreateCalled(account, inputData);
    }

    function getCreateId() external view returns (uint) { return createId; }
    function getAdminAccount() external view returns (bytes32) { return adminAccount; }
}




