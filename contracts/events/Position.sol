// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

string constant ABI = "event AssetPosition(bytes32 indexed account, bytes32 asset, bytes32 meta, uint value, uint queryId)";

/// @notice Emitted when the reported value of an asset-backed position changes or is observed.
/// A value of 0 should be interpreted as a closed position.
abstract contract AssetPositionEvent is EventEmitter {
    /// @param account Account identifier that owns or is associated with the position.
    /// @param asset Asset identifier for the asset class.
    /// @param meta Asset metadata slot carrying the position context.
    /// @param value Context-specific position value; 0 indicates a closed position.
    /// @param queryId Query ID associated with the position lookup or reporting context.
    event AssetPosition(bytes32 indexed account, bytes32 asset, bytes32 meta, uint value, uint queryId);

    constructor() {
        emit EventAbi(ABI);
    }
}
