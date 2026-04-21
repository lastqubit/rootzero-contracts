// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @notice Asset and amount pair used across ledger, command, and block flows.
struct AssetAmount {
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
    /// @dev Token amount in the asset's native units.
    uint amount;
}

/// @notice User-scoped amount that matches the ENTRY block shape.
struct UserAmount {
    /// @dev User account identifier.
    bytes32 account;
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
    /// @dev Token amount in the asset's native units.
    uint amount;
}

/// @notice User-scoped asset position that matches the POSITION block shape.
struct Position {
    /// @dev User account identifier.
    bytes32 account;
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
}

/// @notice Transfer payload used across the pipeline and later consumed by settlement.
struct Tx {
    /// @dev Sender account identifier.
    bytes32 from;
    /// @dev Destination account identifier.
    bytes32 to;
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
    /// @dev Transfer amount in the asset's native units.
    uint amount;
}
