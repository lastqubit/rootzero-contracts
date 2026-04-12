// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

string constant ABI = "event Asset(uint indexed host, bytes32 name, uint32 prefix)";

/// @notice Emitted when an asset is registered or updated on a host.
abstract contract AssetEvent is EventEmitter {
    /// @param host Host node ID that registered the asset.
    /// @param name Asset identifier.
    /// @param prefix 4-byte type prefix of the asset ID.
    event Asset(uint indexed host, bytes32 name, uint32 prefix);

    constructor() {
        emit EventAbi(ABI);
    }
}



