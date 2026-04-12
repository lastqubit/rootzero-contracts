// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {BalanceEvent} from "../events/Balance.sol";

/// @dev Thrown when a debit would reduce a balance below zero.
error InsufficientFunds();

/// @title Balances
/// @notice On-chain ledger for per-account, per-asset token balances.
/// Balances are keyed by `(account, assetKey)` where `assetKey` is the
/// value returned by `Assets.key(asset, meta)`.
abstract contract Balances is BalanceEvent {
    /// @dev account -> assetKey -> balance (in the asset's native units).
    mapping(bytes32 account => mapping(bytes32 assetKey => uint amount)) internal balances;

    /// @notice Deduct `amount` from an account balance and return the new balance.
    /// Reverts with `InsufficientFunds` if the current balance is less than `amount`.
    /// @param account Account identifier.
    /// @param assetKey Storage key for the (asset, meta) pair.
    /// @param amount Amount to deduct.
    /// @return balance New balance after the debit.
    function debitFrom(bytes32 account, bytes32 assetKey, uint amount) internal returns (uint balance) {
        balance = balances[account][assetKey];
        if (balance < amount) revert InsufficientFunds();
        unchecked {
            balance -= amount;
        }
        balances[account][assetKey] = balance;
    }

    /// @notice Add `amount` to an account balance and return the new balance.
    /// @param account Account identifier.
    /// @param assetKey Storage key for the (asset, meta) pair.
    /// @param amount Amount to credit.
    /// @return balance New balance after the credit.
    function creditTo(bytes32 account, bytes32 assetKey, uint amount) internal returns (uint balance) {
        balance = balances[account][assetKey] += amount;
    }
}
