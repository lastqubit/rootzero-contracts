// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when an asset support status is updated on a host.
abstract contract AssetStatusEvent is EventEmitter {
    string private constant ABI = "event AssetStatus(uint indexed host, bytes32 asset, bytes32 meta, uint status)";

    /// @param host Host node ID that manages this listing.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param status Asset support status. Zero means unsupported; nonzero means supported.
    event AssetStatus(uint indexed host, bytes32 asset, bytes32 meta, uint status);

    constructor() {
        emit EventAbi(ABI);
    }
}



