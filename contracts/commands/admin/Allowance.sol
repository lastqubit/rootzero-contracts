// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, CommandContext, Keys} from "./Base.sol";
import {Cursors, Cur} from "../../Cursors.sol";
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
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("allowance", Keys.Empty, Keys.Allowance, Keys.Empty, 0, false, true);
    }

    /// @notice Apply each ALLOWANCE block in the admin request.
    /// @param c Admin command context; `c.input` must contain ALLOWANCE blocks.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function allowance(CommandContext calldata c) external onlyAdmin(c.account) returns (bytes memory, bytes memory) {
        (Cur memory input, ) = openInput(c.input, descriptor);

        while (input.i < input.len) {
            (uint peer, bytes32 asset, uint amount) = input.unpackAllowance();
            allowance(peer, asset, amount);
        }
        return ("", "");
    }
}
