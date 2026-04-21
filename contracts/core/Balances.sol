// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {BalanceEvent} from "../events/Balance.sol";

/// @dev Thrown when a debit would reduce a balance below zero.
error InsufficientFunds();

/// @title Balances
/// @notice On-chain ledger for per-account, per-slot balances.
/// Higher-level modules decide how slots are derived and validated.
abstract contract Balances is BalanceEvent {
    /// @dev account -> slot -> balance.
    mapping(bytes32 account => mapping(bytes32 slot => uint amount)) internal balances;

    /// @notice Add `amount` to an account balance and return the new balance.
    /// @param account Account identifier.
    /// @param slot Storage slot for the position being credited.
    /// @param amount Amount to credit.
    /// @return balance New balance after the credit.
    function creditTo(bytes32 account, bytes32 slot, uint amount) internal returns (uint balance) {
        balance = balances[account][slot] += amount;
    }

    /// @notice Deduct `amount` from an account balance and return the new balance.
    /// Reverts with `InsufficientFunds` if the current balance is less than `amount`.
    /// @param account Account identifier.
    /// @param slot Storage slot for the position being debited.
    /// @param amount Amount to deduct.
    /// @return balance New balance after the debit.
    function debitFrom(bytes32 account, bytes32 slot, uint amount) internal returns (uint balance) {
        balance = balances[account][slot];
        if (balance < amount) revert InsufficientFunds();
        unchecked {
            balance -= amount;
        }
        balances[account][slot] = balance;
    }
}
