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

/// @title PostHook
/// @notice Hook for posting one transaction between accounts.
abstract contract PostHook {
    /// @notice Override to post one transaction.
    function post(bytes32 from, bytes32 to, bytes32 asset, uint amount) internal virtual;
}

/// @title RepayHook
/// @notice Hook for repaying one account liability.
abstract contract RepayHook {
    /// @notice Override to repay `debt` denominated in `liability` for `account`.
    function repay(bytes32 account, bytes32 liability, uint debt) internal virtual;
}

/// @title SettleHook
/// @notice Hook for settling one asset-liability position.
abstract contract SettleHook {
    /// @notice Override to settle one position for `account`.
    function settle(bytes32 account, bytes32 asset, uint amount, bytes32 liability, uint debt) internal virtual;
}

/// @title Settlement
/// @notice Default account-hook implementation for transaction posting and position settlement.
abstract contract Settlement is PostHook, SettleHook, RepayHook, DebitAccountHook, CreditAccountHook {
    /// @notice Post one transaction by debiting its source and crediting its destination.
    /// Returns without calling either hook when `amount` is zero and skips either
    /// operation when the corresponding account is zero.
    function post(bytes32 from, bytes32 to, bytes32 asset, uint amount) internal virtual override {
        if (amount == 0) return;
        if (from != 0) debitAccount(from, asset, amount);
        if (to != 0) creditAccount(to, asset, amount);
    }

    /// @notice Repay one liability by debiting it from the account.
    /// Skips the debit when `debt` is zero.
    function repay(bytes32 account, bytes32 liability, uint debt) internal virtual override {
        if (debt != 0) debitAccount(account, liability, debt);
    }

    /// @notice Settle one position by crediting its asset and debiting its liability.
    /// Skips either operation when its corresponding amount is zero.
    function settle(
        bytes32 account,
        bytes32 asset,
        uint amount,
        bytes32 liability,
        uint debt
    ) internal virtual override {
        if (amount != 0) creditAccount(account, asset, amount);
        if (debt != 0) debitAccount(account, liability, debt);
    }
}
