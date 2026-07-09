// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AdminBase, CommandContext, Keys } from "./Base.sol";
import { Cursors, Cur } from "../../Cursors.sol";
using Cursors for Cur;

/// @title Authorize
/// @notice Admin command that grants authorization to a list of node IDs.
/// Each NODE block in the request is authorized on the host.
/// Only callable by the admin account.
abstract contract Authorize is AdminBase {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("authorize", Keys.Empty, Keys.Node, Keys.Empty, 0, false, true);
    }

    /// @notice Authorize each NODE block in the admin request.
    /// @param c Admin command context; `c.request` must contain NODE blocks.
    /// @return Empty output state.
    function authorize(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory input, ) = openInput(c.request, descriptor);

        while (input.i < input.len) {
            uint node = input.unpackNode();
            setNode(node, true);
        }
        return "";
    }
}





