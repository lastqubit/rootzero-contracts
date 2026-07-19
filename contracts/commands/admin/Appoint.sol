// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AdminBase, CommandContext, Keys } from "./Base.sol";
import { Cursors, Cur } from "../../Cursors.sol";
using Cursors for Cur;

/// @title Appoint
/// @notice Admin command that grants guardian status to a list of account IDs.
/// Each ACCOUNT block in the request is enabled as a guardian on the host.
/// Only callable by the admin account.
abstract contract Appoint is AdminBase {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("appoint", Keys.Empty, Keys.Account, Keys.Empty, 0, false, true);
    }

    /// @notice Appoint each ACCOUNT block in the admin request as a guardian.
    /// @param c Admin command context; `c.input` must contain ACCOUNT blocks.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function appoint(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory, bytes memory) {
        (Cur memory input, ) = openInput(c.input, descriptor);

        while (input.i < input.len) {
            bytes32 account = input.unpackAccount();
            setGuardian(account, true);
        }
        return ("", "");
    }
}
