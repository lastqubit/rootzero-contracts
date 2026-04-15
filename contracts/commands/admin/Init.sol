// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, State } from "../Base.sol";
import { Cursors, Cur } from "../../Cursors.sol";

string constant NAME = "init";

using Cursors for Cur;

/// @title Init
/// @notice Admin command that runs host initialization logic via a virtual hook.
/// The full request is passed to `init` as a cursor. Only callable by the admin account.
abstract contract Init is CommandBase {
    uint internal immutable initId = commandId(NAME);

    constructor(string memory input) {
        emit Command(host, NAME, input, initId, State.Empty, State.Empty, false);
    }

    /// @notice Override to run host initialization logic.
    /// @param input Cursor over the full request byte stream.
    function init(Cur memory input) internal virtual;

    function init(
        CommandContext calldata c
    ) external onlyAdmin(c.account) onlyCommand(initId, c.target) returns (bytes memory) {
        Cur memory input = cursor(c.request);
        init(input);
        return "";
    }
}







