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

/// @notice Account-scoped asset shape.
struct AccountAsset {
    /// @dev Account identifier.
    bytes32 account;
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
}

/// @notice Account-scoped amount shape used by payout and holding blocks.
struct AccountAmount {
    /// @dev Account identifier.
    bytes32 account;
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
    /// @dev Token amount in the asset's native units.
    uint amount;
}

/// @notice Host-scoped asset and amount shape.
struct HostAmount {
    /// @dev Host node identifier.
    uint host;
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
    /// @dev Token amount in the asset's native units.
    uint amount;
}

/// @notice Host-scoped account asset shape.
struct HostAccountAsset {
    /// @dev Host node identifier.
    uint host;
    /// @dev Account identifier.
    bytes32 account;
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
}

/// @notice Host-scoped account amount shape.
struct HostAccountAmount {
    /// @dev Host node identifier.
    uint host;
    /// @dev Account identifier.
    bytes32 account;
    /// @dev Asset identifier.
    bytes32 asset;
    /// @dev Asset metadata slot.
    bytes32 meta;
    /// @dev Token amount in the asset's native units.
    uint amount;
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
