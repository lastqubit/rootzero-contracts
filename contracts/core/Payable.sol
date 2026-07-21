// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Budget, Values} from "../utils/Value.sol";
import {Cursors} from "../Cursors.sol";
import {ReceivedEvent} from "../events/Received.sol";
import {Actions} from "../utils/Actions.sol";
import {NativeAsset} from "./Runtime.sol";
import {max128} from "../utils/Utils.sol";

/// @title Payable
/// @notice Abstract mixin for entrypoints that accept native value (`msg.value`).
/// Provides shared helpers for mutable native-value budgets.
abstract contract Payable is NativeAsset, ReceivedEvent {
    /// @notice Open a native-value budget from the current call's `msg.value`.
    /// @return Budget initialized with the full `msg.value`.
    function openValue() internal view returns (Budget memory) {
        return Budget({remaining: msg.value});
    }

    /// @notice Return the current call's native value as a checked uint128.
    /// @return value Current `msg.value` in wei.
    function msgValue() internal view returns (uint128 value) {
        return uint128(max128(msg.value));
    }

    /// @notice Deduct the EVM value lane from a packed resource word and return it.
    /// @dev EVM resources use the low 128 bits as native value/endowment.
    /// @param budget Mutable budget to deduct from.
    /// @param resources Packed resources.
    /// @return value Native value to forward in wei.
    function useValue(Budget memory budget, uint resources) internal pure returns (uint128 value) {
        value = uint128(resources);
        Values.use(budget, value);
    }

    /// @notice Drain a native-value budget into a credit-only TRANSACTION block.
    /// @dev Emits `Received` with `Actions.Refund` when a transaction is created.
    /// @param budget Mutable budget whose remaining value is drained.
    /// @param account Destination account to credit with the remaining native value.
    /// @return transaction Encoded TRANSACTION block, or empty bytes when the budget is empty.
    function end(
        Budget memory budget,
        bytes32 account
    ) internal returns (bytes memory transaction) {
        uint amount = Values.drain(budget);
        if (amount == 0) return "";

        transaction = Cursors.toTransactionBlock(bytes32(0), account, nativeAsset, amount);
        emit Received(account, nativeAsset, amount, Actions.Refund, 0);
    }

}
