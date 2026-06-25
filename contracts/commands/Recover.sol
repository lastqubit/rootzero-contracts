// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, Keys} from "./Base.sol";
import {Payable} from "../core/Payable.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

abstract contract RecoverContextPayableHook {
    /// @notice Override to recover one committed context witness.
    /// @param target Recovery handler node ID.
    /// @param key Commitment or recovery lookup key.
    /// @param resources Chain resources assigned to the recovery attempt.
    /// @param context Cursor scoped to the embedded CONTEXT witness block.
    /// @param budget Mutable native-value budget available to the recovery attempt.
    function recoverContext(uint target, bytes32 key, uint resources, Cur memory context, Budget memory budget) internal virtual;
}

/// @title RecoverContextPayable
/// @notice Command that forwards ContextRecovery request blocks to a virtual hook.
/// Produces no output state.
abstract contract RecoverContextPayable is CommandBase, Payable, RecoverContextPayableHook {
    uint internal immutable recoverContextPayableId = commandId(this.recoverContextPayable.selector);

    constructor() {
        emit Command(host, recoverContextPayableId, "1:0:0", Schemas.ContextRecovery, Keys.Empty, Keys.Empty, true);
        emit Labeled(recoverContextPayableId, bytes32(0), "recoverContextPayable");
    }

    /// @notice Recover each ContextRecovery block in the command request.
    /// @param c Command context; `c.request` must contain ContextRecovery blocks.
    /// @return Empty output state.
    function recoverContextPayable(CommandContext calldata c) external payable onlyCommand returns (bytes memory) {
        (Cur memory request, , ) = Cursors.init(c.request, 1);
        Budget memory budget = openValue();

        while (request.i < request.len) {
            (uint target, bytes32 key, uint resources, Cur memory context) = request.unpackContextRecovery();
            recoverContext(target, key, resources, context, budget);
        }

        closeValue(c.account, budget);
        request.complete();
        return "";
    }
}
