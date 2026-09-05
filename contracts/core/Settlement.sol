// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title DebitHostHook
/// @notice Hook for exactly debiting funds held or controlled directly by a host.
abstract contract DebitHostHook {
    /// @notice Override to debit exactly `amount` of `asset` from the host.
    /// @dev Returning successfully asserts that the complete amount was debited.
    /// The hook must revert if it cannot debit the exact amount. Fees must not
    /// reduce the amount made available to the consuming operation.
    /// @param asset Asset identifier.
    /// @param amount Exact amount to debit.
    function debitHost(bytes32 asset, uint amount) internal virtual;
}

/// @title CreditHostHook
/// @notice Hook for crediting funds held or controlled directly by a host.
abstract contract CreditHostHook {
    /// @notice Override to credit `amount` of `asset` to the host.
    /// @dev Returning successfully asserts that the complete amount was credited.
    /// The hook must revert if it cannot credit the complete amount.
    /// @param asset Asset identifier.
    /// @param amount Exact amount to credit.
    function creditHost(bytes32 asset, uint amount) internal virtual;
}

/// @title DebitAccountHook
/// @notice Hook for exactly debiting externally managed account funds.
abstract contract DebitAccountHook {
    /// @notice Override to debit exactly `amount` from externally managed `account` funds.
    /// @dev Returning successfully asserts that the complete amount was debited. The
    /// hook must revert if it cannot debit the exact amount. Internal bookkeeping fees
    /// must not reduce the amount made available to the consuming operation.
    /// @param account Source account identifier.
    /// @param asset Asset identifier.
    /// @param amount Exact amount to debit.
    function debitAccount(bytes32 account, bytes32 asset, uint amount) internal virtual;
}

/// @title CreditAccountHook
/// @notice Hook for crediting externally managed account funds.
abstract contract CreditAccountHook {
    /// @notice Override to credit externally managed funds to `account`.
    /// @dev Returning successfully asserts that the complete amount was credited.
    /// The hook must revert if it cannot credit the complete amount.
    /// @param account Destination account identifier.
    /// @param asset Asset identifier.
    /// @param amount Exact amount to credit.
    function creditAccount(bytes32 account, bytes32 asset, uint amount) internal virtual;
}

/// @title PostHook
/// @notice Hook for posting one transaction between accounts.
abstract contract PostHook {
    /// @notice Override to post one transaction.
    /// @dev Returning successfully asserts that the complete transaction was posted.
    /// The hook must revert if it cannot apply the complete amount according to
    /// its account and zero-account policy.
    /// @param from Source account identifier, or zero when no debit side exists.
    /// @param to Destination account identifier, or zero when no credit side exists.
    /// @param asset Asset identifier.
    /// @param amount Exact amount to post.
    function post(bytes32 from, bytes32 to, bytes32 asset, uint amount) internal virtual;
}

/// @title RepayHook
/// @notice Hook for fully repaying one account liability.
abstract contract RepayHook {
    /// @notice Override to satisfy `debt` denominated in `liability` for `account`.
    /// @dev Returning successfully asserts that the complete exact-net `debt` was
    /// satisfied. Partial fulfillment is invalid because the consuming command emits
    /// no debt remainder. Revert if the complete quantity cannot be satisfied. Fees
    /// and sourcing costs must be paid in addition to, and must not reduce, `debt`.
    /// @param account Account whose liability is repaid.
    /// @param liability Liability identifier.
    /// @param debt Exact debt amount to repay.
    function repay(bytes32 account, bytes32 liability, uint debt) internal virtual;
}

/// @title SettleHook
/// @notice Hook for fully settling one asset-liability position.
abstract contract SettleHook {
    /// @notice Override to settle one position for `account`.
    /// @dev Returning successfully asserts that the complete exact-net `debt` was
    /// satisfied. Partial fulfillment is invalid because the consuming command emits
    /// no debt remainder. Revert if the complete quantity cannot be satisfied. Fees
    /// and sourcing costs must be paid in addition to, and must not reduce, `debt`.
    /// @param account Account whose position is settled.
    /// @param asset Asset-side identifier.
    /// @param amount Exact asset-side amount.
    /// @param liability Liability-side identifier.
    /// @param debt Exact liability-side debt amount.
    function settle(bytes32 account, bytes32 asset, uint amount, bytes32 liability, uint debt) internal virtual;
}

/// @title Settlement
/// @notice Default account-hook implementation for transaction posting and position settlement.
abstract contract Settlement is PostHook, DebitAccountHook, CreditAccountHook, SettleHook, RepayHook {
    /// @notice Post one transaction by debiting its source and crediting its destination.
    /// Returns without calling either hook when `amount` is zero and skips either
    /// operation when the corresponding account is zero.
    /// @param from Source account identifier, or zero to skip the debit.
    /// @param to Destination account identifier, or zero to skip the credit.
    /// @param asset Asset identifier.
    /// @param amount Exact amount to post.
    function post(bytes32 from, bytes32 to, bytes32 asset, uint amount) internal virtual override {
        if (amount == 0) return;
        if (from != 0) debitAccount(from, asset, amount);
        if (to != 0) creditAccount(to, asset, amount);
    }

    /// @notice Fully repay one exact-net liability by debiting it from the account.
    /// @dev Skips the debit when `debt` is zero. `debitAccount` is exact-or-revert,
    /// so successful return satisfies the complete debt quantity.
    /// @param account Account whose liability is repaid.
    /// @param liability Liability identifier.
    /// @param debt Exact debt amount to repay.
    function repay(bytes32 account, bytes32 liability, uint debt) internal virtual override {
        if (debt != 0) debitAccount(account, liability, debt);
    }

    /// @notice Fully settle one position by crediting its asset and repaying its liability.
    /// @dev A successful return means the complete exact-net `debt` was satisfied.
    /// Skips either operation when its corresponding amount is zero, including position
    /// sides encoded as absent with a zero identifier and quantity.
    /// @param account Account whose position is settled.
    /// @param asset Asset-side identifier.
    /// @param amount Exact asset-side amount.
    /// @param liability Liability-side identifier.
    /// @param debt Exact liability-side debt amount.
    function settle(
        bytes32 account,
        bytes32 asset,
        uint amount,
        bytes32 liability,
        uint debt
    ) internal virtual override {
        repay(account, liability, debt);
        if (amount != 0) creditAccount(account, asset, amount);
    }
}
