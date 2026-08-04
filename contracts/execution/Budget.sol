// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @notice Mutable native-value budget shared across internal calls.
struct Budget {
    /// @dev Remaining unspent native value in wei.
    uint remaining;
}

/// @title Budgets
/// @notice Opening and mutation helpers for standalone native-value budgets.
library Budgets {
    /// @dev Thrown when an operation attempts to spend more value than remains.
    error InsufficientValue();

    /// @notice Open a standalone budget containing the current call value.
    /// @return budget Budget initialized with `msg.value`.
    function open() internal view returns (Budget memory budget) {
        budget.remaining = msg.value;
    }

    /// @notice Deduct the EVM value lane of `resources` from `budget`.
    /// @dev EVM resources use the low 128 bits as native value/endowment.
    /// @param budget Mutable budget to debit.
    /// @param resources Packed resources whose low 128 bits contain native value.
    /// @return value Native value to forward in wei.
    function use(Budget memory budget, uint resources) internal pure returns (uint128 value) {
        value = uint128(resources);
        if (value > budget.remaining) revert InsufficientValue();
        budget.remaining -= value;
    }

    /// @notice Remove and return all remaining value from `budget`.
    /// @param budget Mutable budget to drain.
    /// @return value Native value removed from the budget.
    function drain(Budget memory budget) internal pure returns (uint value) {
        value = budget.remaining;
        budget.remaining = 0;
    }
}
