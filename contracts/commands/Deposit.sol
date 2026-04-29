// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { CommandContext, CommandBase, CommandPayable, Keys } from "./Base.sol";
import { Cursors, Cur, Schemas, Writer, Writers } from "../Cursors.sol";
import { Budget, Values } from "../utils/Value.sol";

string constant DEPOSIT = "deposit";
string constant DEPOSIT_PAYABLE = "depositPayable";

using Cursors for Cur;
using Writers for Writer;

abstract contract DepositHook {
    /// @notice Override to receive externally sourced funds for `account`.
    /// Called once per AMOUNT block. A matching BALANCE block is appended to the
    /// output after each call.
    /// @param account Destination account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount received.
    function deposit(bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal virtual;
}

abstract contract DepositPayableHook {
    /// @notice Override to receive externally sourced funds for `account`.
    /// Called once per AMOUNT block. A matching BALANCE block is appended to the
    /// output after each call.
    /// @param account Destination account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount received.
    /// @param budget Mutable native-value budget drawn from `msg.value`.
    function deposit(bytes32 account, bytes32 asset, bytes32 meta, uint amount, Budget memory budget) internal virtual;
}

/// @title Deposit
/// @notice Command that receives externally sourced assets and records them as BALANCE state.
/// Use `deposit` for assets arriving from outside the protocol (e.g. ERC-20 transfers, ETH).
/// For internal balance deductions, use `debitAccount` instead.
abstract contract Deposit is CommandBase, DepositHook {
    uint internal immutable depositId = commandId(DEPOSIT);

    constructor() {
        emit Command(host, depositId, DEPOSIT, Schemas.Amount, Keys.Empty, Keys.Balance, false);
    }

    function deposit(
        CommandContext calldata c
    ) external onlyCommand(c.account) returns (bytes memory) {
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

/// @title DepositPayable
/// @notice Command that receives externally sourced assets and records them as BALANCE state.
/// Use `depositPayable` when the hook needs tracked access to `msg.value` via a mutable budget.
abstract contract DepositPayable is CommandPayable, DepositPayableHook {
    uint internal immutable depositPayableId = commandId(DEPOSIT_PAYABLE);

    constructor() {
        emit Command(host, depositPayableId, DEPOSIT_PAYABLE, Schemas.Amount, Keys.Empty, Keys.Balance, true);
    }

    function depositPayable(
        CommandContext calldata c
    ) external payable onlyCommand(c.account) returns (bytes memory) {
        (Cur memory request, uint count, ) = cursor(c.request, 1);
        Writer memory writer = Writers.allocBalances(count);
        Budget memory budget = Values.fromMsg();

        while (request.i < request.bound) {
            (bytes32 asset, bytes32 meta, uint amount) = request.unpackAmount();
            deposit(c.account, asset, meta, amount, budget);
            writer.appendBalance(asset, meta, amount);
        }

        settleValue(c.account, budget);
        return request.complete(writer);
    }
}







