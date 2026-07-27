// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @title SchemaEvent
/// @notice Emitted during host deployment to publish a block spec and payload schema.
/// Block keys are opaque `bytes4` tags. Standard protocol blocks use
/// keccak-derived keys by convention, but custom block keys only need to be
/// unique within the publishing host/schema context.
abstract contract SchemaEvent is EventEmitter {
    string private constant ABI = "event Schema(uint indexed host, uint spec, string body, bytes32 name)";

    /// @param host Host node ID that publishes this block schema.
    /// @param spec Block specification being defined by `host`.
    /// @param body Schema DSL string describing the block payload body.
    /// @param name Optional block alias used by endpoint descriptors and nested schemas.
    event Schema(uint indexed host, uint spec, string body, bytes32 name);

    constructor() {
        emit EventAbi(ABI);
    }
}
