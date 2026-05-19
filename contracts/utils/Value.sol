// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @notice Mutable native-value budget drawn down as sub-calls consume ETH.
struct Budget {
    /// @dev Remaining unspent native value in wei.
    uint remaining;
}

/// @title Values
/// @notice Native-value budget mutation helpers.
library Values {
    /// @dev Thrown when a call attempts to spend more native value than remains in the budget.
    error InsufficientValue();

    /// @notice Deduct `amount` from the budget and return it.
    /// Reverts if `amount` exceeds `budget.remaining`.
    /// @param budget Mutable budget to deduct from.
    /// @param amount Native value to spend in wei.
    /// @return The same `amount`, ready to forward to a callee.
    function use(Budget memory budget, uint amount) internal pure returns (uint) {
        if (amount > budget.remaining) revert InsufficientValue();
        budget.remaining -= amount;
        return amount;
    }
}
