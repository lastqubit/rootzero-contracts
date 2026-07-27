// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Specs} from "../codec/Specs.sol";
import {Execution, Executions} from "../execution/Execution.sol";
import {EndpointEvent} from "../events/Endpoint.sol";
import {LabeledEvent} from "../events/Labeled.sol";
import {SchemaEvent} from "../events/Schema.sol";
import {Descriptors} from "../utils/Descriptors.sol";
import {Runtime} from "./Runtime.sol";

/// @title EndpointBase
/// @notice Shared endpoint metadata helpers.
abstract contract EndpointBase is Runtime, EndpointEvent, LabeledEvent, SchemaEvent {
    /// @notice Finalize an execution output and return its encoded block stream.
    /// @param exec Completed endpoint execution.
    /// @return Encoded output block stream.
    function closeExecution(Execution memory exec) internal pure returns (bytes memory) {
        return Executions.finish(exec);
    }

    /// @notice Open an endpoint input stream with an expected batch count.
    /// @param source Input block stream to open.
    /// @param descriptor Packed endpoint descriptor.
    /// @param batches Required batch count, or zero to accept the input count.
    /// @return exec Execution with its output buffer metadata initialized for the input batch count.
    function openInput(
        bytes calldata source,
        uint descriptor,
        uint batches
    ) internal view returns (Execution memory exec) {
        return Executions.openInput(source, descriptor, batches);
    }

    /// @notice Annotate a block spec as a generic LIST item.
    function many(uint spec) internal pure returns (uint) {
        return Specs.withContainer(spec, Specs.List);
    }

    /// @notice Annotate a block spec with an explicit descriptor group size.
    function group(uint spec, uint8 size) internal pure returns (uint) {
        return Specs.withGroup(spec, size);
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
        spec = Specs.create(bytes4(key), min, max, hint);
        emit Schema(host, spec, body, name);
    }

    /// @notice Create and publish endpoint metadata with a default label.
    /// @param id Endpoint node ID.
    /// @param name Default human-readable endpoint label.
    /// @param state State block specification.
    /// @param input Input block specification.
    /// @param output Output block specification.
    /// @param funded Whether the endpoint accepts nonzero native value.
    /// @param admin Whether the endpoint is restricted to the admin account.
    /// @return descriptor Packed endpoint lane metadata and flags.
    function endpoint(
        uint id,
        string memory name,
        uint state,
        uint input,
        uint output,
        bool funded,
        bool admin
    ) internal returns (uint descriptor) {
        descriptor = Descriptors.pack(state, input, output, funded, admin);
        emit Endpoint(host, id, descriptor);
        emit Labeled(id, bytes32(0), name);
    }
}
