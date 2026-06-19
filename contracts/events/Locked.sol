// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when an account locks an asset in a protocol operation.
abstract contract LockedEvent is EventEmitter {
    string private constant ABI = "event Locked(bytes32 indexed account, bytes32 asset, uint amount, uint32 action, uint context)";

    /// @param account Account identifier that locked the asset.
    /// @param asset Asset identifier.
    /// @param amount Amount locked.
    /// @param action Primary operation hint from `Actions`.
    /// @param context Reserved context value for future use.
    event Locked(bytes32 indexed account, bytes32 asset, uint amount, uint32 action, uint context);

    constructor() {
        emit EventAbi(ABI);
    }
}
