// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Execution, Executions, CommandBase, Keys, Lanes, Specs } from "./Base.sol";
import { Specs } from "../Cursors.sol";

using Executions for Execution;

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
    /// @param exec Mutable execution carrying the remaining native-value budget.
    function deposit(bytes32 account, bytes32 asset, uint amount, Execution memory exec) internal virtual;
}

/// @title Deposit
/// @notice Command that receives externally sourced assets and records them as BALANCE state.
/// Use `deposit` for assets arriving from outside the protocol (e.g. ERC-20 transfers, ETH).
/// For internal balance deductions, use `debitAccount` instead.
abstract contract Deposit is CommandBase, DepositHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("deposit", Specs.Empty, Specs.Amount, Specs.Balance, 0, false, false);
    }

    /// @notice Deposit AMOUNT request blocks into the command account and output matching BALANCE blocks.
    /// @param input AMOUNT block stream.
    /// @return BALANCE block stream matching the deposited amounts.
    /// @return Empty transaction stream.
    function deposit(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackAmount(Lanes.Input);
            deposit(account, asset, amount);
            exec.outputBalance(asset, amount);
        }

        return closeCommand(exec, account);
    }
}

/// @title DepositPayable
/// @notice Command that receives externally sourced assets and records them as BALANCE state.
/// Use `depositPayable` when the hook needs tracked access to `msg.value` via a mutable budget.
abstract contract DepositPayable is CommandBase, DepositPayableHook {
    uint private immutable descriptor;

    constructor() {
        (, descriptor) = command("depositPayable", Specs.Empty, Specs.Amount, Specs.Balance, 0, true, false);
    }

    /// @notice Deposit AMOUNT request blocks with access to a mutable native-value budget.
    /// @param input AMOUNT block stream.
    /// @return BALANCE block stream matching the deposited amounts.
    /// @return Remaining native value as a refund transaction stream.
    function depositPayable(
        bytes32 account,
        bytes calldata,
        bytes calldata input
    ) external payable onlyCommand returns (bytes memory, bytes memory) {
        Execution memory exec = openInput(input, descriptor, 0);

        while (exec.more()) {
            (bytes32 asset, uint amount) = exec.unpackAmount(Lanes.Input);
            deposit(account, asset, amount, exec);
            exec.outputBalance(asset, amount);
        }

        return closeCommand(exec, account);
    }
}







