// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted to attach a human-readable namespaced label to a node ID.
abstract contract LabeledEvent is EventEmitter {
    string private constant ABI = "event Labeled(uint indexed id, bytes32 namespace, string name)";

    /// @param id Node or capability ID being labeled.
    /// @param namespace Label namespace.
    /// @param name Human-readable name within the namespace.
    event Labeled(uint indexed id, bytes32 namespace, string name);

    constructor() {
        emit EventAbi(ABI);
    }
}
