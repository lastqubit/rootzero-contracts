// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {CommandContext, CommandPayable, Keys} from "../Base.sol";
import {Cursors, Cur, Schemas} from "../../Cursors.sol";
import {Budget, Values} from "../../utils/Value.sol";
import {Ids} from "../../utils/Ids.sol";

using Cursors for Cur;

string constant NAME = "executePayable";

/// @title ExecutePayable
/// @notice Admin command that forwards raw calldata to one or more target nodes.
/// Each CALL block specifies a target node ID, native value, and raw calldata payload.
/// Only callable by the admin account.
abstract contract ExecutePayable is CommandPayable {
    uint internal immutable executePayableId = commandId(NAME);

    constructor() {
        emit Command(host, executePayableId, NAME, Schemas.Call, Keys.Empty, Keys.Empty, true);
    }

    function executePayable(CommandContext calldata c) external payable onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, , ) = cursor(c.request, 1);
        Budget memory budget = Values.fromMsg();

        while (request.i < request.bound) {
            (uint target, uint value, bytes calldata data) = request.unpackCall();
            address addr = Ids.nodeAddr(target);
            callAddr(addr, Values.use(budget, value), data);
        }

        request.complete();
        settleValue(c.account, budget);
        return "";
    }
}
