// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Blocks} from "../codec/Blocks.sol";
import {Specs} from "../codec/Specs.sol";
import {AnnotationEvent} from "../events/Annotation.sol";
import {Runtime} from "../core/Runtime.sol";

/// @title Schema
/// @notice Emits standard block-schema annotations for the current host.
/// @dev Schema annotations accumulate for distinct block keys. For a trusted
/// emitter, the latest schema for the same block key replaces the earlier claim.
abstract contract Schema is Runtime, AnnotationEvent {
    /// @notice Construct and publish an unnamed context-local block specification.
    /// @param key Context-local key value.
    /// @param min Minimum accepted payload length.
    /// @param max Maximum accepted payload length; zero means unbounded.
    /// @param hint Initial per-block payload capacity.
    /// @param body Schema DSL string describing the block payload body.
    /// @return spec The context-local block specification.
    function schema(
        uint32 key,
        uint32 min,
        uint32 max,
        uint32 hint,
        string memory body
    ) internal returns (uint spec) {
        return schema(key, min, max, hint, body, bytes32(0));
    }

    /// @notice Construct and publish a context-local block specification.
    /// @param key Context-local key value.
    /// @param min Minimum accepted payload length.
    /// @param max Maximum accepted payload length; zero means unbounded.
    /// @param hint Initial per-block payload capacity.
    /// @param body Schema DSL string describing the block payload body.
    /// @param name Schema alias name, or zero for unnamed schemas.
    /// @return spec The context-local block specification.
    function schema(
        uint32 key,
        uint32 min,
        uint32 max,
        uint32 hint,
        string memory body,
        bytes32 name
    ) internal returns (uint spec) {
        return schema(Specs.create(key, min, max, hint), body, name);
    }

    /// @notice Construct and publish an unnamed exact-size context-local block specification.
    /// @param key Context-local key value.
    /// @param size Exact payload length and initial per-block payload capacity.
    /// @param body Schema DSL string describing the block payload body.
    /// @return spec The context-local block specification.
    function schema(uint32 key, uint32 size, string memory body) internal returns (uint spec) {
        return schema(key, size, body, bytes32(0));
    }

    /// @notice Construct and publish an exact-size context-local block specification.
    /// @param key Context-local key value.
    /// @param size Exact payload length and initial per-block payload capacity.
    /// @param body Schema DSL string describing the block payload body.
    /// @param name Schema alias name, or zero for unnamed schemas.
    /// @return spec The context-local block specification.
    function schema(uint32 key, uint32 size, string memory body, bytes32 name) internal returns (uint spec) {
        return schema(Specs.create(key, size), body, name);
    }

    /// @notice Publish an unnamed, already constructed block specification for the current host.
    /// @param spec Packed block specification.
    /// @param body Schema DSL string describing the block payload body.
    /// @return The published block specification.
    function schema(uint spec, string memory body) internal returns (uint) {
        return schema(spec, body, bytes32(0));
    }

    /// @notice Publish an already constructed block specification for the current host.
    /// @param spec Packed block specification.
    /// @param body Schema DSL string describing the block payload body.
    /// @param name Schema alias name, or zero for unnamed schemas.
    /// @return The published block specification.
    function schema(uint spec, string memory body, bytes32 name) internal returns (uint) {
        emit Annotation(host, Blocks.schema(spec, body, name));
        return spec;
    }
}
