// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, State } from "./Base.sol";
import { Cursors, Cur, Schemas, Tx } from "../Cursors.sol";
using Cursors for Cur;

string constant NAME = "transfer";
string constant INPUT = string.concat(Schemas.Amount, "&", Schemas.Recipient);

abstract contract TransferHook {
    /// @notice Override to execute a single transfer record from the request pipeline.
    /// Called once per bundled AMOUNT+RECIPIENT pair in the request.
    /// @param value Decoded transfer record (from, to, asset, meta, amount).
    function transfer(Tx memory value) internal virtual;
}

/// @title Transfer
/// @notice Command that transfers assets from a caller to recipients specified in
/// bundled AMOUNT+RECIPIENT request blocks. Produces no state output.
/// The virtual `transfer(value)` hook is called once per bundle.
abstract contract Transfer is CommandBase, TransferHook {
    uint internal immutable transferId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, INPUT, transferId, State.Empty, State.Empty);
    }

    /// @notice Override to customize request parsing or batching for transfers.
    /// The default implementation iterates bundles and calls `transfer(value)` for each.
    /// @param from Source account identifier.
    /// @param request Full request bytes.
    /// @return Empty bytes (transfers produce no state output).
    function transfer(bytes32 from, bytes calldata request) internal virtual returns (bytes memory) {
        (Cur memory input, , ) = cursor(request, 1);
        Tx memory value;
        value.from = from;

        while (input.i < input.bound) {
            Cur memory bundle = input.bundle();
            value.to = bundle.unpackRecipient();
            (value.asset, value.meta, value.amount) = bundle.unpackAmount();
            transfer(value);
        }

        input.complete();
        return "";
    }

    function transfer(
        CommandContext calldata c
    ) external payable onlyCommand(transferId, c.target) returns (bytes memory) {
        return transfer(c.account, c.request);
    }
}






