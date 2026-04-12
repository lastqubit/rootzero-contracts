// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, State } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
using Cursors for Cur;

string constant NAME = "unauthorize";

/// @title Unauthorize
/// @notice Admin command that revokes authorization from a list of node IDs.
/// Each NODE block in the request is deauthorized on the host.
/// Only callable by the admin account.
abstract contract Unauthorize is CommandBase {
    uint internal immutable unauthorizeId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Node, unauthorizeId, State.Empty, State.Empty);
    }

    function unauthorize(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(unauthorizeId, c.target) returns (bytes memory) {
        (Cur memory request, , ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            uint node = request.unpackNode();
            access(node, false);
        }

        request.complete();
        return "";
    }
}




