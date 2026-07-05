// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, Keys} from "./Base.sol";
import {Payable} from "../core/Payable.sol";
import {RecoverHook} from "../core/Portal.sol";
import {Cursors, Cur, Schemas} from "../Cursors.sol";
import {Budget} from "../utils/Value.sol";

using Cursors for Cur;

/// @title RecoverPayable
/// @notice Command that forwards recover request blocks to a virtual hook.
/// Recovery is witness-driven: the command account pays and receives leftover
/// value settlement, but the recovered subject is defined by each witness.
/// Produces no output state.
abstract contract RecoverPayable is CommandBase, Payable, RecoverHook {
    uint internal immutable recoverPayableId = commandId(this.recoverPayable.selector);

    constructor() {
        emit Command(host, recoverPayableId, "1:0:0", Schemas.Recover, Keys.Empty, Keys.Empty, true);
        emit Labeled(recoverPayableId, bytes32(0), "recoverPayable");
    }

    /// @notice Recover each recover block in the command request.
    /// @param c Command context; `c.request` must contain Recover blocks.
    /// @return Empty output state.
    function recoverPayable(CommandContext calldata c) external payable onlyCommand returns (bytes memory) {
        (Cur memory request, , ) = Cursors.init(c.request, 1);
        Budget memory budget = openValue();

        while (request.i < request.len) {
            (uint handler, uint resources, bytes32 key, bytes calldata witness) = request.unpackRecover();
            recover(handler, key, witness, useValue(budget, resources));
        }

        closeValue(c.account, budget);
        request.complete();
        return "";
    }
}
