// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, Keys } from "./Base.sol";
import { Payable } from "../core/Payable.sol";
import { Cursors, Cur, Writer, Writers } from "../Cursors.sol";
import { Budget } from "../utils/Value.sol";

using Cursors for Cur;
using Writers for Writer;

abstract contract DepositHook {
    /// @notice Override to receive externally sourced funds for `account`.
    /// Called once per AMOUNT block. A matching BALANCE block is appended to the
    /// output after each call.
    /// @param account Destination account identifier.
    /// @param asset Asset identifier.
    /// @param amount Amount received.
    function deposit(bytes32 account, bytes32 asset, uint amount) internal virtual;
}

abstract contract DepositPayableHook {
    /// @notice Override to receive externally sourced funds for `account`.
    /// Called once per AMOUNT block. A matching BALANCE block is appended to the
    /// output after each call.
    /// @param account Destination account identifier.
    /// @param asset Asset identifier.
    /// @param amount Amount received.
    /// @param budget Mutable native-value budget drawn from `msg.value`.
    function deposit(bytes32 account, bytes32 asset, uint amount, Budget memory budget) internal virtual;
}

/// @title Deposit
/// @notice Command that receives externally sourced assets and records them as BALANCE state.
/// Use `deposit` for assets arriving from outside the protocol (e.g. ERC-20 transfers, ETH).
/// For internal balance deductions, use `debitAccount` instead.
abstract contract Deposit is CommandBase, DepositHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("deposit", Keys.Empty, Keys.Amount, Keys.Balance, 0, false, false);
    }

    /// @notice Deposit AMOUNT request blocks into the command account and output matching BALANCE blocks.
    /// @param c Command context; `c.input` must contain AMOUNT blocks.
    /// @return BALANCE block stream matching the deposited amounts.
    /// @return Empty transaction stream.
    function deposit(
        CommandContext calldata c
    ) external onlyCommand returns (bytes memory, bytes memory) {
        (Cur memory input, uint outputs) = openInput(c.input, descriptor);
        Writer memory output = Writers.allocBalances(outputs);

        while (input.i < input.len) {
            (bytes32 asset, uint amount) = input.unpackAmount();
            deposit(c.account, asset, amount);
            output.appendBalance(asset, amount);
        }

        return (end(output), "");
    }
}

/// @title DepositPayable
/// @notice Command that receives externally sourced assets and records them as BALANCE state.
/// Use `depositPayable` when the hook needs tracked access to `msg.value` via a mutable budget.
abstract contract DepositPayable is CommandBase, Payable, DepositPayableHook {
    bytes32 private immutable descriptor;

    constructor() {
        (, descriptor) = command("depositPayable", Keys.Empty, Keys.Amount, Keys.Balance, 0, true, false);
    }

    /// @notice Deposit AMOUNT request blocks with access to a mutable native-value budget.
    /// @param c Command context; `c.input` must contain AMOUNT blocks.
    /// @return BALANCE block stream matching the deposited amounts.
    /// @return Remaining native value as a refund transaction stream.
    function depositPayable(
        CommandContext calldata c
    ) external payable onlyCommand returns (bytes memory, bytes memory) {
        (Cur memory input, uint outputs) = openInput(c.input, descriptor);
        Writer memory output = Writers.allocBalances(outputs);
        Budget memory budget = openValue();

        while (input.i < input.len) {
            (bytes32 asset, uint amount) = input.unpackAmount();
            deposit(c.account, asset, amount, budget);
            output.appendBalance(asset, amount);
        }

        return (end(output), end(budget, c.account));
    }
}







