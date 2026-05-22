// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when assets enter or leave a host.
abstract contract AssetFlowEvent is EventEmitter {
    string private constant ABI = "event AssetFlow(bytes32 indexed account, bytes32 asset, bytes32 meta, int amount)";

    /// @param account Account identifier the asset flow belongs to.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Signed amount; positive values enter the host, negative values leave it.
    event AssetFlow(bytes32 indexed account, bytes32 asset, bytes32 meta, int amount);

    constructor() {
        emit EventAbi(ABI);
    }
}

/// @notice Emitted when an asset listing is updated on a host.
abstract contract AssetListingEvent is EventEmitter {
    string private constant ABI = "event AssetListing(uint indexed host, bytes32 asset, bytes32 meta, bool active)";

    /// @param host Host node ID that manages this listing.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param active True if the listing is currently active.
    event AssetListing(uint indexed host, bytes32 asset, bytes32 meta, bool active);

    constructor() {
        emit EventAbi(ABI);
    }
}



