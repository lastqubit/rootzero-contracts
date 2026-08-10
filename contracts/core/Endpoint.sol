// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Execution, Executions} from "../execution/Execution.sol";
import {EndpointEvent} from "../events/Endpoint.sol";
import {Label} from "../annotations/Label.sol";
import {Schema} from "../annotations/Schema.sol";
import {Descriptors} from "../codec/Descriptors.sol";

/// @title EndpointBase
/// @notice Shared endpoint metadata helpers.
abstract contract EndpointBase is EndpointEvent, Label, Schema {
    /// @notice Create and publish endpoint metadata with a default label.
    /// @param id Endpoint node ID.
    /// @param name Default human-readable endpoint label.
    /// @param state State block specification.
    /// @param input Input block specification.
    /// @param output Output block specification.
    /// @param transactions Number of transaction blocks produced per batch, or zero for none.
    /// @param flags Packed endpoint behavior flags.
    /// @return descriptor Packed endpoint lane metadata and flags.
    function endpoint(
        uint id,
        string memory name,
        uint state,
        uint input,
        uint output,
        uint8 transactions,
        uint8 flags
    ) internal returns (uint descriptor) {
        descriptor = Descriptors.create(state, input, output, transactions, flags);
        return endpoint(id, name, descriptor);
    }

    /// @notice Publish already constructed endpoint metadata with a default label.
    /// @param id Endpoint node ID.
    /// @param name Default human-readable endpoint label.
    /// @param descriptor Packed endpoint lane metadata and flags.
    /// @return The published endpoint descriptor.
    function endpoint(uint id, string memory name, uint descriptor) internal returns (uint) {
        emit Endpoint(host, id, descriptor);
        label(id, bytes32(0), name);
        return descriptor;
    }

    /// @notice Finalize an execution output and return its encoded block stream.
    /// @param exec Completed endpoint execution.
    /// @return Encoded output block stream.
    function close(Execution memory exec) internal pure returns (bytes memory) {
        return Executions.finish(exec);
    }
}

/// @title InputEndpointBase
/// @notice Shared input opening for endpoint families that have only an input lane.
/// Commands intentionally do not inherit this base because they must open state
/// and input together through `openCommand`.
abstract contract InputEndpointBase is EndpointBase {
    /// @notice Open an endpoint input stream with an expected batch count.
    function openInput(
        bytes calldata input,
        uint descriptor,
        uint batches
    ) internal view returns (Execution memory exec) {
        return Executions.openInput(input, descriptor, batches);
    }
}
