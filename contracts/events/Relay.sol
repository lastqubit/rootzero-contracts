// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted when an account records an outbound relay reference.
abstract contract RelayEvent is EventEmitter {
    string private constant ABI = "event Relay(bytes32 indexed account, uint portal, uint resources, bytes32 key, bytes32 digest)";

    /// @param account Account that owns the relayed context.
    /// @param portal Destination portal implementation's host ID.
    /// @param resources Chain-specific resources assigned to the relay.
    /// @param key Relay correlation or recovery lookup key.
    /// @param digest Digest of the relayed payload or canonical envelope.
    event Relay(bytes32 indexed account, uint portal, uint resources, bytes32 key, bytes32 digest);

    constructor() {
        emit EventAbi(ABI);
    }
}
