// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when an account locks an asset in a protocol operation.
abstract contract LockedEvent is EventEmitter {
    string private constant ABI = "event Locked(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint context)";

    /// @param account Account identifier that locked the asset.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount locked.
    /// @param context Operation context identifier associated with this lock.
    /// The low 32 bits are the primary `Actions` hint; higher bits are reserved.
    event Locked(bytes32 indexed account, bytes32 asset, bytes32 meta, uint amount, uint context);

    constructor() {
        emit EventAbi(ABI);
    }
}
