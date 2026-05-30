// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { EventEmitter } from "./Emitter.sol";

/// @notice Emitted when an asset moves from one account to another.
abstract contract TransferEvent is EventEmitter {
    string private constant ABI = "event Transfer(bytes32 indexed from, bytes32 to, bytes32 asset, bytes32 meta, uint amount, uint32 action, uint context)";

    /// @param account Source account identifier.
    /// @param to Destination account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Amount transferred.
    /// @param action Primary operation hint from `Actions`.
    /// @param context Reserved context value for future use.
    event Transfer(bytes32 indexed account, bytes32 to, bytes32 asset, bytes32 meta, uint amount, uint32 action, uint context);

    constructor() {
        emit EventAbi(ABI);
    }
}
