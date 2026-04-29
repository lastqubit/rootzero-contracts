// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "../Base.sol";
import { Cursors, Cur } from "../../Cursors.sol";

string constant NAME = "init";

using Cursors for Cur;

abstract contract InitHook {
    /// @notice Override to run host initialization logic.
    /// @param input Cursor over the full request byte stream.
    function init(Cur memory input) internal virtual;
}

/// @title Init
/// @notice Admin command that runs host initialization logic via a virtual hook.
/// The full request is passed to `init` as a cursor. Only callable by the admin account.
abstract contract Init is CommandBase, InitHook {
    uint internal immutable initId = commandId(NAME);

    constructor(string memory input) {
        emit Command(host, initId, NAME, input, Keys.Empty, Keys.Empty, false);
    }

    function init(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        Cur memory input = cursor(c.request);
        init(input);
        return "";
    }
}







