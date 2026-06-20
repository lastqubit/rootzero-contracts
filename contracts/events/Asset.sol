// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when a host declares the preimage for an opaque asset ID.
abstract contract AssetEvent is EventEmitter {
    string private constant ABI = "event Asset(uint indexed host, bytes32 asset, bytes preimage)";

    /// @param host Host node ID that manages this asset declaration.
    /// @param asset Asset identifier, typically `0x00 || bytes31(hash(preimage))`.
    /// @param preimage Canonical preimage used to derive or resolve the opaque asset ID.
    /// The first byte is a format/hash tag; `0x01` means keccak256.
    event Asset(uint indexed host, bytes32 asset, bytes preimage);

    constructor() {
        emit EventAbi(ABI);
    }
}

/// @notice Emitted when an asset support status is updated on a host.
abstract contract AssetStatusEvent is EventEmitter {
    string private constant ABI = "event AssetStatus(uint indexed host, bytes32 asset, uint status)";

    /// @param host Host node ID that manages this listing.
    /// @param asset Asset identifier.
    /// @param status Asset support status. Zero means unsupported; nonzero means supported.
    event AssetStatus(uint indexed host, bytes32 asset, uint status);

    constructor() {
        emit EventAbi(ABI);
    }
}



