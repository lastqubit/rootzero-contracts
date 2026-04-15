// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, State } from "../Base.sol";
import { Cursors, Cur } from "../../Cursors.sol";

string constant NAME = "destroy";

using Cursors for Cur;

/// @title Destroy
/// @notice Admin command that runs host teardown logic via a virtual hook.
/// The full request is passed to `destroy` as a cursor. Only callable by the admin account.
abstract contract Destroy is CommandBase {
    uint internal immutable destroyId = commandId(NAME);

    constructor(string memory input) {
        emit Command(host, NAME, input, destroyId, State.Empty, State.Empty, false);
    }

    /// @notice Override to run host teardown or destruction logic.
    /// @param input Cursor over the full request byte stream.
    function destroy(Cur memory input) internal virtual;

    function destroy(
        CommandContext calldata c
    ) external onlyAdmin(c.account) onlyCommand(destroyId, c.target) returns (bytes memory) {
        Cur memory input = cursor(c.request);
        destroy(input);
        return "";
    }
}







