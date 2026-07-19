// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AdminBase, CommandContext, Keys } from "./Base.sol";
import { Cursors, Cur } from "../../Cursors.sol";
using Cursors for Cur;

/// @title Dismiss
/// @notice Admin command that revokes guardian status from a list of account IDs.
/// Each ACCOUNT block in the request is disabled as a guardian on the host.
/// Only callable by the admin account.
abstract contract Dismiss is AdminBase {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("dismiss", Keys.Empty, Keys.Account, Keys.Empty, 0, false, true);
    }

    /// @notice Dismiss each ACCOUNT block in the admin request from guardian status.
    /// @param c Admin command context; `c.input` must contain ACCOUNT blocks.
    /// @return state Empty output state.
    /// @return transactions Empty transaction stream.
    function dismiss(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory state, bytes memory transactions) {
        (Cur memory input, ) = openInput(c.input, descriptor);

        while (input.i < input.len) {
            bytes32 account = input.unpackAccount();
            setGuardian(account, false);
        }
        return ("", "");
    }
}
