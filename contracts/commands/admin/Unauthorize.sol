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
    uint internal immutable unauthorizeId = commandId(this.unauthorize.selector);

    constructor() {
        emit Admin(host, unauthorizeId, "1:0:0", Schemas.Node, Keys.Empty, Keys.Empty, false, false);
        emit Labeled(unauthorizeId, bytes32(0), "unauthorize");
    }

    /// @notice Unauthorize each NODE block in the admin request.
    /// @param c Admin command context; `c.request` must contain NODE blocks.
    /// @return Empty output state.
    function unauthorize(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, , ) = Cursors.init(c.request, 0, 1);

        while (request.i < request.len) {
            uint node = request.unpackNode();
            setNode(node, false);
        }

        request.complete();
        return "";
    }
}





