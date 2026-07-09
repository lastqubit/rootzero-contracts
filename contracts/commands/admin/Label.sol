// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, CommandContext, Keys} from "./Base.sol";
import {Cursors, Cur} from "../../Cursors.sol";
using Cursors for Cur;

/// @title Label
/// @notice Admin command that publishes namespaced labels for node IDs.
/// Each LABEL block in the request emits one `Labeled` event. Only callable by
/// the admin account.
abstract contract Label is AdminBase {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("label", Keys.Empty, Keys.Label, Keys.Empty, 0, false, true);
    }

    /// @notice Publish each LABEL block in the admin request.
    /// @param c Admin command context; `c.request` must contain LABEL blocks.
    /// @return Empty output state.
    function label(CommandContext calldata c) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory input, ) = openInput(c.request, descriptor);

        while (input.i < input.len) {
            (uint node, bytes32 namespace, string memory name) = input.unpackLabel();
            emit Labeled(node, namespace, name);
        }
        return "";
    }
}
