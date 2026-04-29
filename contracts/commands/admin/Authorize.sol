// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
using Cursors for Cur;

string constant NAME = "authorize";

/// @title Authorize
/// @notice Admin command that grants authorization to a list of node IDs.
/// Each NODE block in the request is authorized on the host.
/// Only callable by the admin account.
abstract contract Authorize is CommandBase {
    uint internal immutable authorizeId = commandId(NAME);

    constructor() {
        emit Command(host, authorizeId, NAME, Schemas.Node, Keys.Empty, Keys.Empty, false);
    }

    function authorize(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, , ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            uint node = request.unpackNode();
            authorize(node);
        }

        request.complete();
        return "";
    }
}





