// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title State
/// @notice Command state type discriminants.
/// Each constant tags the shape of the encoded state block stream stored
/// in a command's metadata slot, allowing commands to select the correct
/// decode path without inspecting the raw bytes.
library State {
    /// @dev No state; the command produces or expects an empty state stream.
    uint8 constant Empty = 0x0001;
    /// @dev State stream contains STEP blocks (sub-command invocations).
    uint8 constant Steps = 0x0002;
    /// @dev State stream contains BALANCE blocks.
    uint8 constant Balances = 0x0003;
    /// @dev State stream contains TRANSACTION blocks.
    uint8 constant Transactions = 0x0004;
    /// @dev State stream contains HOSTED_BALANCE custody blocks.
    uint8 constant Custodies = 0x0005;
    /// @dev State stream contains claim records.
    uint8 constant Claims = 0x0006;
}
