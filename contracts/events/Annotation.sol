// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {EventEmitter} from "./Emitter.sol";

/// @notice Emitted to attach encoded annotation blocks to an entity.
/// @dev `data` is a protocol block stream. A single block is the conventional
/// case, but related annotations may be emitted together. Annotations are claims
/// by the emitting contract, and each block key defines its annotation type.
/// Consumers process events in log order and blocks in stream order, then apply
/// the identity and merge rules defined by each annotation type. The event does
/// not impose a universal replacement policy: a type may replace, accumulate,
/// preserve history, or define its own revocation convention.
abstract contract AnnotationEvent is EventEmitter {
    string private constant ABI = "event Annotation(uint indexed entity, bytes data)";

    /// @param entity Entity being annotated.
    /// @param data Encoded annotation block stream, conventionally containing one block.
    event Annotation(uint indexed entity, bytes data);

    constructor() {
        emit EventAbi(ABI);
    }
}
