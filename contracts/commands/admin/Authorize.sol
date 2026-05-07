// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
import { AdminEvent } from "../../events/Admin.sol";
using Cursors for Cur;

/// @title Authorize
/// @notice Admin command that grants authorization to a list of node IDs.
/// Each NODE block in the request is authorized on the host.
/// Only callable by the admin account.
abstract contract Authorize is CommandBase, AdminEvent {
    string private constant NAME = "authorize";

    uint internal immutable authorizeId = commandId(NAME);

    constructor() {
        emit Admin(host, authorizeId, NAME, "1:0:0", Schemas.Node, Keys.Empty, Keys.Empty, false);
    }

    function authorize(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            uint node = request.unpackNode();
            authorize(node);
        }

        request.complete();
        return "";
    }
}





