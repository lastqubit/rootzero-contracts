// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {BalanceEvent} from "../events/Balance.sol";

/// @dev Thrown when a debit would reduce a balance below zero.
error InsufficientFunds();

/// @title Balances
/// @notice On-chain ledger for per-asset host balances.
abstract contract Balances {
    /// @dev asset -> balance.
    mapping(bytes32 asset => uint amount) internal balances;

    /// @notice Add `amount` to a host balance and return the new balance.
    /// @param asset Unique asset identifier for the balance being credited.
    /// @param amount Amount to credit.
    /// @return balance New balance after the credit.
    function credit(bytes32 asset, uint amount) internal returns (uint balance) {
        balance = balances[asset] += amount;
    }

    /// @notice Deduct `amount` from a host balance and return the new balance.
    /// Reverts with `InsufficientFunds` if the current balance is less than `amount`.
    /// @param asset Unique asset identifier for the balance being debited.
    /// @param amount Amount to deduct.
    /// @return balance New balance after the debit.
    function debit(bytes32 asset, uint amount) internal returns (uint balance) {
        balance = balances[asset];
        if (balance < amount) revert InsufficientFunds();
        unchecked {
            balance -= amount;
        }
        balances[asset] = balance;
    }
}

/// @title AccountBalances
/// @notice On-chain ledger for per-account, per-asset balances.
abstract contract AccountBalances is BalanceEvent {
    /// @dev account -> asset -> balance.
    mapping(bytes32 account => mapping(bytes32 asset => uint amount)) internal accountBalances;

    /// @notice Add `amount` to an account balance and return the new balance.
    /// @param account Account identifier.
    /// @param asset Unique asset identifier for the position being credited.
    /// @param amount Amount to credit.
    /// @return balance New balance after the credit.
    function creditTo(bytes32 account, bytes32 asset, uint amount) internal returns (uint balance) {
        balance = accountBalances[account][asset] += amount;
    }

    /// @notice Deduct `amount` from an account balance and return the new balance.
    /// Reverts with `InsufficientFunds` if the current balance is less than `amount`.
    /// @param account Account identifier.
    /// @param asset Unique asset identifier for the position being debited.
    /// @param amount Amount to deduct.
    /// @return balance New balance after the debit.
    function debitFrom(bytes32 account, bytes32 asset, uint amount) internal returns (uint balance) {
        balance = accountBalances[account][asset];
        if (balance < amount) revert InsufficientFunds();
        unchecked {
            balance -= amount;
        }
        accountBalances[account][asset] = balance;
    }
}
