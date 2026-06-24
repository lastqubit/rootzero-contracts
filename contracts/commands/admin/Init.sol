// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AdminBase, CommandContext, Keys } from "./Base.sol";
import { Cursors, Cur } from "../../Cursors.sol";

using Cursors for Cur;

abstract contract InitHook {
    /// @notice Override to run host initialization logic.
    /// @param input Cursor over the full request byte stream.
    function init(Cur memory input) internal virtual;
}

/// @title Init
/// @notice Admin command that runs host initialization logic via a virtual hook.
/// The full request is passed to `init` as a cursor. Only callable by the admin account.
abstract contract Init is AdminBase, InitHook {
    uint internal immutable initId = commandId(this.init.selector);

    constructor(string memory input) {
        emit Admin(host, initId, "1:0:0", input, Keys.Empty, Keys.Empty, false);
        emit Labeled(initId, bytes32(0), "init");
    }

    /// @notice Run host initialization logic over the full admin request.
    /// @param c Admin command context; `c.request` is passed through as a cursor.
    /// @return Empty output state.
    function init(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        init(Cursors.open(c.request));
        return "";
    }
}







