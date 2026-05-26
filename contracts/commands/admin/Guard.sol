// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
import { AdminEvent } from "../../events/Admin.sol";
using Cursors for Cur;

/// @title Guard
/// @notice Admin command that grants guardian status to a list of account IDs.
/// Each ACCOUNT block in the request is enabled as a guardian on the host.
/// Only callable by the admin account.
abstract contract Guard is CommandBase, AdminEvent {
    string private constant NAME = "guard";

    uint internal immutable guardCommandId = commandId(NAME);

    constructor() {
        emit Admin(host, guardCommandId, NAME, "1:0:0", Schemas.Account, Keys.Empty, Keys.Empty, false);
    }

    function guard(
        CommandContext calldata c
    ) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            bytes32 account = request.unpackAccount();
            setGuardian(account, true);
        }

        request.close();
        return "";
    }
}
