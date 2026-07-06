// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AdminBase, CommandContext, Keys } from "./Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
using Cursors for Cur;

/// @title Authorize
/// @notice Admin command that grants authorization to a list of node IDs.
/// Each NODE block in the request is authorized on the host.
/// Only callable by the admin account.
abstract contract Authorize is AdminBase {
    uint internal immutable authorizeId = commandId(this.authorize.selector);

    constructor() {
        emit Admin(host, authorizeId, "1:0:0", Schemas.Node, Keys.Empty, Keys.Empty, false);
        emit Labeled(authorizeId, bytes32(0), "authorize");
    }

    /// @notice Authorize each NODE block in the admin request.
    /// @param c Admin command context; `c.request` must contain NODE blocks.
    /// @return Empty output state.
    function authorize(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, ) = Cursors.init(c.request, 1);

        while (request.i < request.len) {
            uint node = request.unpackNode();
            setNode(node, true);
        }

        request.complete();
        return "";
    }
}





