// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, Keys} from "./Base.sol";
import {Payable} from "../core/Payable.sol";
import {Cursors, Cur} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

abstract contract RecoverHook {
    /// @notice Override to recover a witness through `handler`.
    /// @param handler Port that should attempt recovery.
    /// @param key Recovery lookup key.
    /// @param witness Witness payload used to prove and replay recovery.
    /// @param value Native EVM value assigned to the recovery attempt.
    function recover(uint handler, bytes32 key, bytes calldata witness, uint128 value) internal virtual;
}

/// @title RecoverPayable
/// @notice Command that forwards recover request blocks to a virtual hook.
/// Recovery is witness-driven: the command account pays and receives leftover
/// value settlement, but the recovered subject is defined by each witness.
/// Produces no output state.
abstract contract RecoverPayable is CommandBase, Payable, RecoverHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("recoverPayable", Keys.Empty, Keys.Recover, Keys.Empty, 0, true, false);
    }

    /// @notice Recover each recover block in the command request.
    /// @param c Command context; `c.request` must contain Recover blocks.
    /// @return Empty output state.
    function recoverPayable(CommandContext calldata c) external payable onlyCommand returns (bytes memory) {
        (Cur memory input, ) = openInput(c.request, descriptor);
        Budget memory budget = openValue();

        while (input.i < input.len) {
            (uint handler, uint resources, bytes32 key, bytes calldata witness) = input.unpackRecover();
            recover(handler, key, witness, useValue(budget, resources));
        }

        closeValue(c.account, budget);
        return "";
    }
}
