// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @dev Thrown when a debit would reduce an escrow below zero.
error InsufficientEscrow();

/// @title Escrows
/// @notice On-chain ledger for amounts reserved outside normal spendable balances.
abstract contract Escrows {
    /// @dev key -> escrowed amount.
    mapping(bytes32 key => uint amount) internal escrows;

    /// @notice Add `amount` to an escrow and return the new balance.
    /// @param key Escrow key derived by the caller.
    /// @param amount Amount to reserve.
    /// @return balance New escrow balance after the credit.
    function creditEscrow(bytes32 key, uint amount) internal returns (uint balance) {
        balance = escrows[key] += amount;
    }

    /// @notice Deduct `amount` from an escrow and return the new balance.
    /// Reverts with `InsufficientEscrow` if the current balance is less than `amount`.
    /// @param key Escrow key derived by the caller.
    /// @param amount Amount to release.
    /// @return balance New escrow balance after the debit.
    function debitEscrow(bytes32 key, uint amount) internal returns (uint balance) {
        balance = escrows[key];
        if (balance < amount) revert InsufficientEscrow();
        unchecked {
            balance -= amount;
        }
        escrows[key] = balance;
    }
}
