// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title DebitAccountHook
/// @notice Hook for debiting externally managed account funds.
abstract contract DebitAccountHook {
    /// @notice Override to debit externally managed funds from `account`.
    /// @param account Source account identifier.
    /// @param asset Asset identifier.
    /// @param amount Amount to debit.
    function debitAccount(bytes32 account, bytes32 asset, uint amount) internal virtual;
}

/// @title CreditAccountHook
/// @notice Hook for crediting externally managed account funds.
abstract contract CreditAccountHook {
    /// @notice Override to credit externally managed funds to `account`.
    /// @param account Destination account identifier.
    /// @param asset Asset identifier.
    /// @param amount Amount to credit.
    function creditAccount(bytes32 account, bytes32 asset, uint amount) internal virtual;
}

/// @title Settlement
/// @notice Settles decoded transactions through debit and credit account hooks.
abstract contract Settlement is DebitAccountHook, CreditAccountHook {
    /// @notice Settle one transaction by debiting its source and crediting its destination.
    /// Returns without calling either hook when `amount` is zero and skips either
    /// operation when the corresponding account is zero.
    /// @param from Source account identifier.
    /// @param to Destination account identifier.
    /// @param asset Asset identifier.
    /// @param amount Token amount.
    function settle(bytes32 from, bytes32 to, bytes32 asset, uint amount) internal {
        if (amount == 0) return;
        if (from != 0) debitAccount(from, asset, amount);
        if (to != 0) creditAccount(to, asset, amount);
    }
}
