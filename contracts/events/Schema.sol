// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted during host deployment to publish a block key and payload schema.
/// Block keys are opaque `bytes4` tags. Standard protocol blocks use
/// keccak-derived keys by convention, but custom block keys only need to be
/// unique within the publishing host/schema context.
abstract contract SchemaEvent is EventEmitter {
    string private constant ABI = "event Schema(uint indexed host, bytes4 key, string schema, bytes32 name)";

    /// @param host Host node ID that publishes this block schema.
    /// @param key Block type key being defined by `host`.
    /// @param schema Schema DSL string describing the block payload body.
    /// @param name Optional block name used to reference this key from endpoint descriptors and nested schemas.
    event Schema(uint indexed host, bytes4 key, string schema, bytes32 name);

    constructor() {
        emit EventAbi(ABI);
    }
}
