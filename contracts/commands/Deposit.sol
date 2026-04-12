// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, State } from "./Base.sol";
import { Cursors, Cur, Schemas, Writer, Writers } from "../Cursors.sol";

string constant NAME = "deposit";

using Cursors for Cur;
using Writers for Writer;

/// @title Deposit
/// @notice Command that receives externally sourced assets and records them as BALANCE state.
/// Use `deposit` for assets arriving from outside the protocol (e.g. ERC-20 transfers, ETH).
/// For internal balance deductions, use `debitAccount` instead.
abstract contract Deposit is CommandBase {
    uint internal immutable depositId = commandId(NAME);

    constructor() {
        emit Command(host, NAME, Schemas.Amount, depositId, State.Empty, State.Balances);
    }

    /// @notice Override to receive externally sourced funds for `account`.
    /// Called once per AMOUNT block. A matching BALANCE block is appended to the
    /// output after each call.
    /// @param account Recipient account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount received.
    function deposit(
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) internal virtual;

    function deposit(
        CommandContext calldata c
    ) external payable onlyCommand(depositId, c.target) returns (bytes memory) {
        (Cur memory request, uint count, ) = cursor(c.request, 1);
        Writer memory writer = Writers.allocBalances(count);

        while (request.i < request.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = request.unpackAmount();
            deposit(c.account, asset, meta, amount);
            writer.appendBalance(asset, meta, amount);
        }

        return request.complete(writer);
    }
}






