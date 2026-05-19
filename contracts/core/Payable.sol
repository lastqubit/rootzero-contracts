// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Budget, Values} from "../utils/Value.sol";

/// @title Payable
/// @notice Abstract mixin for entrypoints that accept native value (`msg.value`).
/// Provides a shared settlement hook for any unspent value remaining in the
/// mutable budget after execution completes.
abstract contract Payable {
    /// @dev Thrown when a payable entrypoint completes with unspent native value.
    /// Override `settleValue` to implement refund or forwarding behavior instead.
    error UnusedValue(uint remaining);

    /// @notice Create a native-value budget from the current call's `msg.value`.
    /// @return Budget initialised with the full `msg.value`.
    function valueBudget() internal view returns (Budget memory) {
        return Budget({remaining: msg.value});
    }

    /// @notice Deduct `amount` from the budget and return it.
    /// @param budget Mutable budget to deduct from.
    /// @param amount Native value to spend.
    /// @return The same `amount`, ready to forward to a callee.
    function useValue(Budget memory budget, uint amount) internal pure returns (uint) {
        return Values.use(budget, amount);
    }

    /// @notice Deduct `amount` from the budget and return it as a new sub-budget.
    /// @param budget Mutable parent budget to deduct from.
    /// @param amount Native value to assign to the sub-budget.
    /// @return A new budget with `amount` remaining.
    function allocateValue(Budget memory budget, uint amount) internal pure returns (Budget memory) {
        return Values.allocate(budget, amount);
    }

    /// @notice Drains the budget and settles any remaining native value.
    /// @dev Calls the amount-based `settleValue` hook only when some value remains.
    /// @param account Account identifier for the current invocation.
    /// @param budget Mutable native-value budget used during execution.
    function settleValue(bytes32 account, Budget memory budget) internal {
        uint value = budget.remaining;
        if (value == 0) return;
        budget.remaining = 0;
        settleValue(account, value);
    }

    /// @notice Handles leftover native value after payable execution has finished.
    /// @dev Override this hook to refund or redirect unused value.
    /// The default implementation rejects any leftover amount.
    /// @param account Account identifier for the current invocation.
    /// @param remaining Unspent native value left in the budget, in wei.
    function settleValue(bytes32 account, uint remaining) internal virtual {
        account;
        revert UnusedValue(remaining);
    }
}
