// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandBase, CommandContext, State } from "../Base.sol";
import { Cursors, Cur, Schemas } from "../../Cursors.sol";
using Cursors for Cur;

string constant NAME = "relocate";

/// @title Relocate
/// @notice Admin command that forwards native value (ETH) to one or more destination hosts.
/// Each FUNDING block in the request specifies a target host node ID and an amount to forward.
/// Only callable by the admin account.
abstract contract Relocate is CommandBase {
    uint internal immutable relocateId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Funding, relocateId, State.Empty, State.Empty);
    }

    function relocate(
        CommandContext calldata c
    ) external payable onlyAdmin(c.account) onlyCommand(relocateId, c.target) returns (bytes memory) {
        (Cur memory request, , ) = cursor(c.request, 1);

        while (request.i < request.bound) {
            (uint host, uint amount) = request.unpackFunding();
            callTo(host, amount, "");
        }

        request.complete();
        return "";
    }
}





