// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted when a host records an outbound dispatch reference.
abstract contract DispatchEvent is EventEmitter {
    string private constant ABI = "event Dispatch(uint indexed host, uint chain, uint resources, bytes32 digest, bytes32 ref)";

    /// @param host Host node ID that owns the dispatch.
    /// @param chain Destination chain/domain node ID.
    /// @param resources Chain-adapter-specific resources assigned to the dispatch.
    /// @param digest Digest of the dispatched payload or canonical envelope.
    /// @param ref Dispatch correlation or recovery reference.
    event Dispatch(uint indexed host, uint chain, uint resources, bytes32 digest, bytes32 ref);

    constructor() {
        emit EventAbi(ABI);
    }
}
