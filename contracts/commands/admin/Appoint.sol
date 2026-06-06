// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
import { AdminEvent } from "../../events/Admin.sol";
using Cursors for Cur;

/// @title Appoint
/// @notice Admin command that grants guardian status to a list of account IDs.
/// Each ACCOUNT block in the request is enabled as a guardian on the host.
/// Only callable by the admin account.
abstract contract Appoint is CommandBase, AdminEvent {
    string private constant NAME = "appoint";

    uint internal immutable appointId = commandId(NAME);

    constructor() {
        emit Admin(host, appointId, NAME, "1:0:0", Schemas.Account, Keys.Empty, Keys.Empty, false, false);
    }

    /// @notice Appoint each ACCOUNT block in the admin request as a guardian.
    /// @param c Admin command context; `c.request` must contain ACCOUNT blocks.
    /// @return Empty output state.
    function appoint(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, , ) = Cursors.init(c.request, 0, 1);

        while (request.i < request.len) {
            bytes32 account = request.unpackAccount();
            setGuardian(account, true);
        }

        request.complete();
        return "";
    }
}
