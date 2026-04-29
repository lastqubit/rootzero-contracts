// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, Keys } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
using Cursors for Cur;

string constant NAME = "allowance";

abstract contract AllowanceHook {
    /// @notice Apply or revoke one host-scoped allowance.
    /// Called once per ALLOWANCE block in the request. Implementations decide
    /// how the allowance is represented, e.g. ERC-20 approval, an internal cap,
    /// or another host-specific authorization record.
    /// @param peer Host node receiving the allowed cap.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Allowed cap amount.
    function allowance(uint peer, bytes32 asset, bytes32 meta, uint amount) internal virtual;
}

/// @title Allowance
/// @notice Admin command that applies cross-host allowance entries via a virtual hook.
/// Each ALLOWANCE block grants or updates a host-scoped asset cap. Only callable by the admin account.
abstract contract Allowance is CommandBase, AllowanceHook {
    uint internal immutable allowanceId = commandId(NAME);

    constructor() {
        emit Command(host, allowanceId, NAME, Schemas.Allowance, Keys.Empty, Keys.Empty, false);
    }

    function allowance(CommandContext calldata c) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, , ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            (uint peer, bytes32 asset, bytes32 meta, uint amount) = request.unpackAllowance();
            allowance(peer, asset, meta, amount);
        }

        request.complete();
        return "";
    }
}
