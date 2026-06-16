// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted to attach a human-readable namespaced label to an entity.
/// @dev Labels are claims by the emitting contract. Any contract may emit a
/// label for any entity, so off-chain indexers must decide which emitters are
/// trusted for each labeled entity or namespace.
abstract contract LabeledEvent is EventEmitter {
    string private constant ABI = "event Labeled(uint indexed entity, bytes32 namespace, string name)";

    /// @param entity Entity being labeled.
    /// @param namespace Label namespace.
    /// @param name Human-readable name within the namespace.
    event Labeled(uint indexed entity, bytes32 namespace, string name);

    constructor() {
        emit EventAbi(ABI);
    }
}
