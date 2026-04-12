// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, State } from "./Base.sol";
import { Cursors, Cur } from "../Cursors.sol";

string constant NAME = "remove";

using Cursors for Cur;

/// @title Remove
/// @notice Generic command that removes or dismantles objects via a virtual hook.
/// The request schema is constructor-defined; `remove` is called once per top-level group.
/// Produces no output state.
abstract contract Remove is CommandBase {
    uint internal immutable removeId = commandId(NAME);

    constructor(string memory input) {
        emit Command(host, NAME, input, removeId, State.Empty, State.Empty);
    }

    /// @dev Override to remove or dismantle an object described by `input`.
    /// Called once per top-level request item.
    function remove(bytes32 account, Cur memory input) internal virtual;

    function remove(CommandContext calldata c) external payable onlyCommand(removeId, c.target) returns (bytes memory) {
        (Cur memory request, , ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            remove(c.account, request);
        }

        request.complete();
        return "";
    }
}





