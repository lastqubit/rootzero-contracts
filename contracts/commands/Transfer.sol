// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Keys } from "./Base.sol";
import { Cursors, Cur, Schemas, Tx } from "../Cursors.sol";
import { Accounts } from "../utils/Accounts.sol";
using Cursors for Cur;

abstract contract TransferHook {
    /// @notice Override to execute a single transfer record from the request pipeline.
    /// Called once per PAYOUT block in the request.
    /// @param value Decoded transfer record (from, to, asset, meta, amount).
    function transfer(Tx memory value) internal virtual;
}

/// @title Transfer
/// @notice Command that transfers assets from a caller to recipients specified in
/// PAYOUT request blocks. Produces no state output.
/// The virtual `transfer(value)` hook is called once per entry.
abstract contract Transfer is CommandBase, TransferHook {
    string private constant NAME = "transfer";

    uint internal immutable transferId = commandId(NAME);

    constructor() {
        emit Command(host, transferId, NAME, Schemas.Payout, Keys.Empty, Keys.Empty, false);
    }

    /// @notice Override to customize request parsing or batching for transfers.
    /// The default implementation iterates entry blocks and calls `transfer(value)` for each.
    /// @param from Source account identifier.
    /// @param request Full request bytes.
    /// @return Empty bytes (transfers produce no state output).
    function transfer(bytes32 from, bytes calldata request) internal virtual returns (bytes memory) {
        (Cur memory input, , ) = cursor(request, 1);
        Tx memory value;
        value.from = from;

        while (input.i < input.bound) {
            (value.to, value.asset, value.meta, value.amount) = input.unpackPayout();
            Accounts.ensure(value.to);
            transfer(value);
        }

        input.complete();
        return "";
    }

    function transfer(
        CommandContext calldata c
    ) external onlyCommand(c.account) returns (bytes memory) {
        return transfer(c.account, c.request);
    }
}
