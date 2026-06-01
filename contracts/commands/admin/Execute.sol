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
/// Each CALL block specifies a target node ID, native value, and raw calldata payload.
/// Only callable by the admin account.
abstract contract ExecutePayable is CommandBase, Payable, AdminEvent {
    string private constant NAME = "executePayable";

    uint internal immutable executePayableId = commandId(NAME);

    constructor() {
        emit Admin(host, executePayableId, NAME, "1:0:0", Schemas.Call, Keys.Empty, Keys.Empty, false, true);
    }

    function executePayable(CommandContext calldata c) external payable onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, ) = Cursors.first(c.request, 1);
        Budget memory budget = valueBudget();

        while (request.i < request.len) {
            (uint target, uint value, bytes calldata data) = request.unpackCall();
            address addr = Ids.nodeAddr(target);
            callAddr(addr, useValue(budget, value), data);
        }

        request.complete();
        return "";
    }
}
