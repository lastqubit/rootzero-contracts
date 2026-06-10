// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
import { AdminEvent } from "../../events/Admin.sol";
using Cursors for Cur;

/// @title Dismiss
/// @notice Admin command that revokes guardian status from a list of account IDs.
/// Each ACCOUNT block in the request is disabled as a guardian on the host.
/// Only callable by the admin account.
abstract contract Dismiss is CommandBase, AdminEvent {
    uint internal immutable dismissId = commandId(this.dismiss.selector);

    constructor() {
        emit Admin(host, dismissId, "1:0:0", Schemas.Account, Keys.Empty, Keys.Empty, false);
        emit Labeled(dismissId, bytes32(0), "dismiss");
    }

    /// @notice Dismiss each ACCOUNT block in the admin request from guardian status.
    /// @param c Admin command context; `c.request` must contain ACCOUNT blocks.
    /// @return Empty output state.
    function dismiss(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, , ) = Cursors.init(c.request, 1);

        while (request.i < request.len) {
            bytes32 account = request.unpackAccount();
            setGuardian(account, false);
        }

        request.complete();
        return "";
    }
}
