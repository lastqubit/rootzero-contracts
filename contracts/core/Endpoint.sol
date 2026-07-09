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
    uint8 private constant Version = 1;
    uint8 private constant FlagFunded = 1 << 0;
    uint8 private constant FlagAdmin = 1 << 1;

    /// @notice Return a descriptor lane for a generic LIST containing `item`.
    function many(bytes4 item) internal pure returns (bytes9) {
        return bytes9(bytes.concat(Keys.List, item));
    }

    /// @notice Return a descriptor lane with an explicit group size.
    function group(bytes9 value, uint8 size) internal pure returns (bytes9) {
        return bytes9(bytes.concat(bytes8(value), bytes1(size)));
    }

    /// @notice Publish a block schema and return its key for descriptor construction.
    function schema(bytes4 key, string memory body, bytes32 name) internal returns (bytes4) {
        emit Schema(host, key, body, name);
        return key;
    }

    /// @dev Split a descriptor lane into its packed key lane and effective group size.
    function splitLane(bytes9 value) private pure returns (uint64 key, uint8 size) {
        uint72 packed = uint72(value);
        key = uint64(packed >> 8);
        if (key == 0) return (0, 0);

        size = uint8(packed);
        if (size == 0) size = 1;
    }

    /// @notice Pack endpoint lanes and flags into a descriptor.
    /// A plain `bytes4` key widens to `[key][0]` and defaults to group 1.
    /// `bytes9(0)` means absent with group 0. `many(item)` returns `[LIST][item]`.
    /// Use `group(lane, size)` for explicit groups other than 1.
    /// Layout:
    /// - bytes 0..7: state lane
    /// - byte 8: state group size
    /// - bytes 9..16: input lane
    /// - byte 17: input group size
    /// - bytes 18..25: output lane
    /// - byte 26: output group size
    /// - byte 27: flags (bit 0: funded, bit 1: admin)
    /// - byte 28: descriptor version
    /// - bytes 29..31: reserved
    function endpoint(
        bytes9 state,
        bytes9 input,
        bytes9 output,
        bool funded,
        bool admin
    ) internal pure returns (bytes32 descriptor) {
        uint8 flags = funded ? FlagFunded : 0;
        if (admin) flags |= FlagAdmin;
        uint packed;
        (uint64 state_, uint8 stateGroup_) = splitLane(state);
        (uint64 input_, uint8 inputGroup_) = splitLane(input);
        (uint64 output_, uint8 outputGroup_) = splitLane(output);

        packed |= uint(state_) << 192;
        packed |= uint(stateGroup_) << 184;
        packed |= uint(input_) << 120;
        packed |= uint(inputGroup_) << 112;
        packed |= uint(output_) << 48;
        packed |= uint(outputGroup_) << 40;
        packed |= uint(flags) << 32;
        packed |= uint(Version) << 24;

        descriptor = bytes32(packed);
    }

    /// @notice Return the state group size from an endpoint descriptor.
    function stateGroup(bytes32 descriptor) internal pure returns (uint8) {
        return uint8(uint(descriptor) >> 184);
    }

    /// @notice Return the input group size from an endpoint descriptor.
    function inputGroup(bytes32 descriptor) internal pure returns (uint8) {
        return uint8(uint(descriptor) >> 112);
    }

    /// @notice Return the output group size from an endpoint descriptor.
    function outputGroup(bytes32 descriptor) internal pure returns (uint8) {
        return uint8(uint(descriptor) >> 40);
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

    /// @notice Publish endpoint metadata and a default label.
    function defineEndpoint(uint host, uint id, bytes32 descriptor, string memory name) internal {
        emit Endpoint(host, id, descriptor);
        emit Labeled(id, bytes32(0), name);
    }
}
