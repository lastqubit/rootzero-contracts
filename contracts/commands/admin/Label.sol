// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, Keys} from "../Base.sol";
import {Cursors, Cur, Schemas} from "../../Cursors.sol";
import {AdminEvent} from "../../events/Admin.sol";
using Cursors for Cur;

/// @title Label
/// @notice Admin command that publishes namespaced labels for node IDs.
/// Each LABEL block in the request emits one `Labeled` event. Only callable by
/// the admin account.
abstract contract Label is CommandBase, AdminEvent {
    uint internal immutable labelId = commandId(this.label.selector);

    constructor() {
        emit Admin(host, labelId, "1:0:0", Schemas.Label, Keys.Empty, Keys.Empty, false, false);
        emit Labeled(labelId, bytes32(0), "label");
    }

    /// @notice Publish each LABEL block in the admin request.
    /// @param c Admin command context; `c.request` must contain LABEL blocks.
    /// @return Empty output state.
    function label(CommandContext calldata c) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, , ) = Cursors.init(c.request, 0, 1);

        while (request.i < request.len) {
            (uint id, bytes32 namespace, string memory name) = request.unpackLabel();
            emit Labeled(id, namespace, name);
        }

        request.complete();
        return "";
    }
}
