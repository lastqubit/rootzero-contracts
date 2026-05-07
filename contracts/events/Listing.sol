// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Listing(uint indexed host, bytes32 asset, bytes32 meta, bool active)";

/// @notice Emitted when an asset listing is updated on a host.
abstract contract ListingEvent is EventEmitter {
    /// @param host Host node ID that manages this listing.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param active True if the listing is currently active.
    event Listing(uint indexed host, bytes32 asset, bytes32 meta, bool active);

    constructor() {
        emit EventAbi(ABI);
    }
}



