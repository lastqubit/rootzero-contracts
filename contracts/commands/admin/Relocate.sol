// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandPayable, State } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
import { Budget, Values } from "../../utils/Value.sol";
using Cursors for Cur;

string constant NAME = "relocatePayable";

/// @title RelocatePayable
/// @notice Admin command that forwards native value (ETH) to one or more destination hosts.
/// Each HOST_FUNDING block in the request specifies a target host node ID and an amount to forward.
/// Only callable by the admin account.
abstract contract RelocatePayable is CommandPayable {
    uint internal immutable relocatePayableId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.HostFunding, relocatePayableId, State.Empty, State.Empty, true);
    }

    function relocatePayable(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) returns (bytes memory) {
        (Cur memory request, , ) = cursor(c.request, 1);
        Budget memory budget = Values.fromMsg();

        while (request.i < request.bound) {
            (uint peer, uint amount) = request.unpackHostFunding();
            callTo(peer, Values.use(budget, amount), "");
        }

        request.complete();
        settleValue(c.account, budget);
        return "";
    }
}






