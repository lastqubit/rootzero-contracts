// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, CommandContext, Keys} from "./Base.sol";
import {Cursors, Cur, Schemas} from "../../Cursors.sol";
using Cursors for Cur;

abstract contract AllowanceHook {
    /// @notice Apply or revoke one host-scoped allowance.
    /// Called once per ALLOWANCE block in the request. Implementations decide
    /// how the allowance is represented, e.g. ERC-20 approval, an internal cap,
    /// or another host-specific authorization record.
    /// @param peer Host node receiving the allowed cap.
    /// @param asset Asset identifier.
    /// @param amount Allowed cap amount.
    function allowance(uint peer, bytes32 asset, uint amount) internal virtual;
}

/// @title Allowance
/// @notice Admin command that applies cross-host allowance entries via a virtual hook.
/// Each ALLOWANCE block grants or updates a host-scoped asset cap. Only callable by the admin account.
abstract contract Allowance is AdminBase, AllowanceHook {
    uint internal immutable allowanceId = commandId(this.allowance.selector);

    constructor() {
        emit Admin(host, allowanceId, "1:0:0", Schemas.Allowance, Keys.Empty, Keys.Empty, false);
        emit Labeled(allowanceId, bytes32(0), "allowance");
    }

    /// @notice Apply each ALLOWANCE block in the admin request.
    /// @param c Admin command context; `c.request` must contain ALLOWANCE blocks.
    /// @return Empty output state.
    function allowance(CommandContext calldata c) external onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, ) = Cursors.init(c.request, 1);

        while (request.i < request.len) {
            (uint peer, bytes32 asset, uint amount) = request.unpackAllowance();
            allowance(peer, asset, amount);
        }

        request.complete();
        return "";
    }
}
