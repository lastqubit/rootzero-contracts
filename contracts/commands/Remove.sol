// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext} from "./Base.sol";
import {SETUP} from "../utils/Channels.sol";
import {Data, DataRef, ROUTE_KEY} from "../Blocks.sol";
using Data for DataRef;

string constant NAME = "remove";

abstract contract Remove is CommandBase {
    uint internal immutable removeId = commandId(NAME);

    constructor(string memory route) {
        emit Command(host, NAME, route, removeId, SETUP, SETUP);
    }

    /// @dev Override to remove or dismantle an object described by `rawRoute`.
    /// Called once per ROUTE block in the request.
    function remove(bytes32 account, DataRef memory rawRoute) internal virtual;

    function remove(CommandContext calldata c) external payable onlyCommand(removeId, c.target) returns (bytes memory) {
        uint q = 0;
        while (q < c.request.length) {
            (DataRef memory ref, uint next) = Data.from(c.request, q);
            if (ref.key != ROUTE_KEY) break;
            remove(c.account, ref);
            q = next;
        }

        return done(0, q);
    }
}
