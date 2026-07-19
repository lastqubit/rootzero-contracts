// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, CommandContext, Keys} from "./Base.sol";
import {Cursors, Cur} from "../../Cursors.sol";
using Cursors for Cur;

/// @title Unauthorize
/// @notice Admin command that revokes authorization from a list of node IDs.
/// Each NODE block in the request is deauthorized on the host.
/// Only callable by the admin account.
abstract contract Unauthorize is AdminBase {
    bytes32 private immutable descriptor;
    uint internal immutable unauthorizeId;

    constructor() {
        (unauthorizeId, descriptor) = command("unauthorize", Keys.Empty, Keys.Node, Keys.Empty, 0, false, true);
    }

    /// @notice Unauthorize each NODE block in the admin request.
    /// @param c Admin command context; `c.input` must contain NODE blocks.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function unauthorize(CommandContext calldata c) external onlyAdmin(c.account) returns (bytes memory, bytes memory) {
        (Cur memory input, ) = openInput(c.input, descriptor);

        while (input.i < input.len) {
            uint node = input.unpackNode();
            setNode(node, false);
        }
        return ("", "");
    }
}
