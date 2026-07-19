// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AdminBase, CommandContext, Keys} from "./Base.sol";
import {Payable} from "../../core/Payable.sol";
import {Cursors, Cur} from "../../Cursors.sol";
import {Budget} from "../../utils/Value.sol";

using Cursors for Cur;

/// @title ExecutePayable
/// @notice Admin command that forwards raw calldata to one or more target nodes.
/// Each CALL block specifies a target node ID, packed resources, and raw calldata payload.
/// Only callable by the admin account.
/// Unspent top-level `msg.value` remains on this host.
abstract contract ExecutePayable is AdminBase, Payable {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("executePayable", Keys.Empty, Keys.Call, Keys.Empty, 0, true, true);
    }

    /// @notice Execute each CALL block in the admin request.
    /// @param c Admin command context; `c.input` must contain CALL blocks.
    /// @return Empty output state.
    /// @return Empty transaction stream.
    function executePayable(CommandContext calldata c) external payable onlyAdmin(c.account) returns (bytes memory, bytes memory) {
        (Cur memory input, ) = openInput(c.input, descriptor);
        Budget memory budget = openValue();

        while (input.i < input.len) {
            (uint target, uint resources, bytes calldata data) = input.unpackCall();
            rawCall(target, useValue(budget, resources), data);
        }
        return ("", "");
    }
}
