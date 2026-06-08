// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "../Base.sol";
import { Cursors, Cur } from "../../Cursors.sol";
import { AdminEvent } from "../../events/Admin.sol";

using Cursors for Cur;

abstract contract DestroyHook {
    /// @notice Override to run host teardown or destruction logic.
    /// @param input Cursor over the full request byte stream.
    function destroy(Cur memory input) internal virtual;
}

/// @title Destroy
/// @notice Admin command that runs host teardown logic via a virtual hook.
/// The full request is passed to `destroy` as a cursor. Only callable by the admin account.
abstract contract Destroy is CommandBase, AdminEvent, DestroyHook {
    uint internal immutable destroyId = commandId(this.destroy.selector);

    constructor(string memory input) {
        emit Admin(host, destroyId, "1:0:0", input, Keys.Empty, Keys.Empty, false, false);
        emit Labeled(destroyId, bytes32(0), "destroy");
    }

    /// @notice Run host teardown logic over the full admin request.
    /// @param c Admin command context; `c.request` is passed through as a cursor.
    /// @return Empty output state.
    function destroy(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        destroy(Cursors.open(c.request));
        return "";
    }
}







