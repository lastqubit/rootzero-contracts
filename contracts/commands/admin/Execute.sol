// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandBase, CommandContext, Keys} from "../Base.sol";
import {Payable} from "../../core/Payable.sol";
import {Cursors, Cur, Schemas} from "../../Cursors.sol";
import {AdminEvent} from "../../events/Admin.sol";
import {Budget} from "../../utils/Value.sol";
import {Ids} from "../../utils/Ids.sol";

using Cursors for Cur;

/// @title ExecutePayable
/// @notice Admin command that forwards raw calldata to one or more target nodes.
/// Each CALL block specifies a target node ID, chain resources, and raw calldata payload.
/// Only callable by the admin account.
/// Unspent top-level `msg.value` remains on this host.
abstract contract ExecutePayable is CommandBase, Payable, AdminEvent {
    uint internal immutable executePayableId = commandId(this.executePayable.selector);

    constructor() {
        emit Admin(host, executePayableId, "1:0:0", Schemas.Call, Keys.Empty, Keys.Empty, true);
        emit Labeled(executePayableId, bytes32(0), "executePayable");
    }

    /// @notice Execute each CALL block in the admin request.
    /// @param c Admin command context; `c.request` must contain CALL blocks.
    /// @return Empty output state.
    function executePayable(CommandContext calldata c) external payable onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, , ) = Cursors.init(c.request, 1);
        Budget memory budget = valueBudget();

        while (request.i < request.len) {
            (uint target, uint resources, bytes calldata data) = request.unpackCall();
            address addr = Ids.nodeAddr(target);
            callAddr(addr, useValue(budget, resources), data);
        }

        request.complete();
        return "";
    }
}
