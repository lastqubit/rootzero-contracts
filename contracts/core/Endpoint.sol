// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cursors, Cur} from "../Cursors.sol";
import {Keys} from "../blocks/Keys.sol";
import {EndpointEvent} from "../events/Endpoint.sol";
import {LabeledEvent} from "../events/Labeled.sol";
import {SchemaEvent} from "../events/Schema.sol";
import {Runtime} from "./Runtime.sol";

/// @title EndpointBase
/// @notice Shared endpoint metadata helpers.
abstract contract EndpointBase is Runtime, EndpointEvent, LabeledEvent, SchemaEvent {
    /// @notice Return an 8-byte lane value for a generic LIST containing `item`.
    function many(bytes4 item) internal pure returns (bytes8) {
        return bytes8(bytes.concat(Keys.List, item));
    }

    /// @notice Append an explicit group size to an 8-byte lane value.
    function group(bytes8 value, uint8 size) internal pure returns (bytes9) {
        return bytes9(bytes.concat(value, bytes1(size)));
    }

    /// @dev Return a lane's effective group size, defaulting non-empty lanes to one.
    function laneGroup(bytes32 descriptor, uint shift) private pure returns (uint8 size) {
        uint72 lane = uint72(uint(descriptor) >> shift);
        if (lane == 0) return 0;

        size = uint8(lane);
        if (size == 0) size = 1;
    }

    /// @dev Pack endpoint lanes and flags into a descriptor.
    /// A non-empty lane with group 0 defaults to group 1; a zero lane is absent.
    /// Layout: `[state:8][group:1][input:8][group:1][output:8][group:1]`
    /// `[flags:1][reserved:4]`. Flag bits: funded = 0, admin = 1.
    function pack(
        bytes9 state,
        bytes9 input,
        bytes9 output,
        bool funded,
        bool admin
    ) private pure returns (uint value) {
        value |= uint(uint72(state)) << 184;
        value |= uint(uint72(input)) << 112;
        value |= uint(uint72(output)) << 40;
        value |= uint(funded ? 1 : 0) << 32;
        value |= uint(admin ? 1 : 0) << 33;
    }

    /// @notice Return the state group size from an endpoint descriptor.
    function stateGroup(bytes32 descriptor) internal pure returns (uint8) {
        return laneGroup(descriptor, 184);
    }

    /// @notice Return the input group size from an endpoint descriptor.
    function inputGroup(bytes32 descriptor) internal pure returns (uint8) {
        return laneGroup(descriptor, 112);
    }

    /// @notice Return the output group size from an endpoint descriptor.
    function outputGroup(bytes32 descriptor) internal pure returns (uint8) {
        return laneGroup(descriptor, 40);
    }

    /// @notice Open an endpoint state stream and return the expected output block count.
    function openState(
        bytes calldata source,
        bytes32 descriptor
    ) internal pure returns (Cur memory state, uint outputs) {
        uint groups;
        (state, groups) = Cursors.init(source, stateGroup(descriptor));
        outputs = groups * outputGroup(descriptor);
    }

    /// @notice Open an endpoint input stream and return the expected output block count.
    function openInput(
        bytes calldata source,
        bytes32 descriptor
    ) internal pure returns (Cur memory input, uint outputs) {
        uint groups;
        (input, groups) = Cursors.init(source, inputGroup(descriptor));
        outputs = groups * outputGroup(descriptor);
    }

    /// @notice Publish a block schema and return its key for descriptor construction.
    function schema(bytes4 key, string memory body, bytes32 name) internal returns (bytes4) {
        emit Schema(host, key, body, name);
        return key;
    }

    /// @notice Create and publish endpoint metadata with a default label.
    function endpoint(
        uint id,
        string memory name,
        bytes9 state,
        bytes9 input,
        bytes9 output,
        bool funded,
        bool admin
    ) internal returns (bytes32 descriptor) {
        descriptor = bytes32(pack(state, input, output, funded, admin));
        emit Endpoint(host, id, descriptor);
        emit Labeled(id, bytes32(0), name);
    }
}
