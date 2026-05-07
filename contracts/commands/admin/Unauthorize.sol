// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
import { AdminEvent } from "../../events/Admin.sol";
using Cursors for Cur;

/// @title Unauthorize
/// @notice Admin command that revokes authorization from a list of node IDs.
/// Each NODE block in the request is deauthorized on the host.
/// Only callable by the admin account.
abstract contract Unauthorize is CommandBase, AdminEvent {
    string private constant NAME = "unauthorize";

    uint internal immutable unauthorizeId = commandId(NAME);

    constructor() {
        emit Admin(host, unauthorizeId, NAME, Schemas.Node, Keys.Empty, Keys.Empty, false);
    }

    function unauthorize(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            uint node = request.unpackNode();
            unauthorize(node);
        }

        request.complete();
        return "";
    }
}





