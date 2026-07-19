// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, CommandContext, Keys} from "./Base.sol";
import {Cursors, Cur} from "../../Cursors.sol";
using Cursors for Cur;

/// @title Authorize
/// @notice Admin command that grants authorization to a list of node IDs.
/// Each NODE block in the request is authorized on the host.
/// Only callable by the admin account.
abstract contract Authorize is AdminBase {
    bytes32 private immutable descriptor;
    uint internal immutable authorizeId;

    constructor() {
        (authorizeId, descriptor) = command("authorize", Keys.Empty, Keys.Node, Keys.Empty, 0, false, true);
    }

    /// @notice Authorize each NODE block in the admin request.
    /// @param c Admin command context; `c.input` must contain NODE blocks.
    /// @return state Empty output state.
    /// @return transactions Empty transaction stream.
    function authorize(CommandContext calldata c) external onlyAdmin(c.account) returns (bytes memory state, bytes memory transactions) {
        (Cur memory input, ) = openInput(c.input, descriptor);

        while (input.i < input.len) {
            uint node = input.unpackNode();
            setNode(node, true);
        }
        return ("", "");
    }
}
