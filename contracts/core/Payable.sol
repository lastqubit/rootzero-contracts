// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Budget, Values} from "../utils/Value.sol";

/// @title Payable
/// @notice Abstract mixin for entrypoints that accept native value (`msg.value`).
/// Provides shared helpers for mutable native-value budgets.
abstract contract Payable {
    /// @dev Thrown when a payable entrypoint completes with unspent native value.
    error UnusedValue(uint remaining);

    /// @notice Open a native-value budget from the current call's `msg.value`.
    /// @return Budget initialized with the full `msg.value`.
    function openValue() internal view returns (Budget memory) {
        return Budget({remaining: msg.value});
    }

    /// @notice Deduct the EVM value lane from a packed resource word and return it.
    /// @dev EVM resources use the low 128 bits as native value/endowment.
    /// @param budget Mutable budget to deduct from.
    /// @param resources Packed chain resources.
    /// @return value Native value to forward in wei.
    function useValue(Budget memory budget, uint resources) internal pure returns (uint128 value) {
        value = uint128(resources);
        Values.use(budget, value);
    }

    /// @notice Close a native-value budget and settle any drained value.
    /// @param account Account identifier for the current invocation.
    /// @param budget Mutable native-value budget to close.
    function closeValue(bytes32 account, Budget memory budget) internal {
        uint value = Values.drain(budget);
        if (value == 0) return;
        settleValue(account, value);
    }

    /// @notice Handle a drained native value amount.
    /// @dev Override to refund or redirect unused value. The default rejects it.
    /// @param account Account identifier for the current invocation.
    /// @param value Drained native value amount to settle, in wei.
    function settleValue(bytes32 account, uint value) internal virtual {
        account;
        revert UnusedValue(value);
    }
}
