// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {ReceivedEvent} from "../events/Received.sol";
import {NativeAsset} from "./Runtime.sol";
import {max128} from "../utils/Utils.sol";

/// @title Payable
/// @notice Abstract mixin for entrypoints that accept native value (`msg.value`).
/// Provides checked access to the current call's native value.
abstract contract Payable is NativeAsset, ReceivedEvent {
    /// @notice Return the current call's native value as a checked uint128.
    /// @return value Current `msg.value` in wei.
    function msgValue() internal view returns (uint128 value) {
        return uint128(max128(msg.value));
    }
}
