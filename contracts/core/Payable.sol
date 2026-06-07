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

    /// @notice Deduct the EVM value lane from a packed resource word and return it.
    /// @dev EVM resources use the low 128 bits as native value/endowment.
    /// @param budget Mutable budget to deduct from.
    /// @param resources Packed chain resources.
    /// @return value Native value to forward in wei.
    function useValue(Budget memory budget, uint resources) internal pure returns (uint128 value) {
        return Values.use(budget, uint128(resources));
    }

    /// @notice Deduct the EVM value lane from a packed resource word as a new sub-budget.
    /// @dev EVM resources use the low 128 bits as native value/endowment.
    /// @param budget Mutable parent budget to deduct from.
    /// @param resources Packed chain resources.
    /// @return A new budget with the EVM value lane remaining.
    function allocateValue(Budget memory budget, uint resources) internal pure returns (Budget memory) {
        return Values.allocate(budget, uint128(resources));
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
