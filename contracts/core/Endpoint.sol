// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Cursors, Cur, Writer, Writers} from "../Cursors.sol";
import {Keys} from "../blocks/Keys.sol";
import {EndpointEvent} from "../events/Endpoint.sol";
import {LabeledEvent} from "../events/Labeled.sol";
import {SchemaEvent} from "../events/Schema.sol";
import {Runtime} from "./Runtime.sol";

/// @title Lane
/// @notice Bit offsets for endpoint descriptor lanes.
library Lane {
    /// @dev Descriptor shift for the state lane.
    uint internal constant State = 184;
    /// @dev Descriptor shift for the input lane.
    uint internal constant Input = 112;
    /// @dev Descriptor shift for the output lane.
    uint internal constant Output = 40;
}

/// @title EndpointBase
/// @notice Shared endpoint metadata helpers.
abstract contract EndpointBase is Runtime, EndpointEvent, LabeledEvent, SchemaEvent {
    /// @notice Finalize an endpoint output writer and return its encoded block stream.
    /// @param output Completed endpoint output writer.
    /// @return Encoded output block stream.
    function end(Writer memory output) internal pure returns (bytes memory) {
        return Writers.finish(output);
    }

    /// @dev Pack endpoint lanes and flags into a descriptor.
    /// A non-empty lane with group 0 defaults to group 1; a zero lane is absent.
    /// Layout: `[state:8][group:1][input:8][group:1][output:8][group:1]`
    /// `[flags:1][reserved:4]`. Flag bits: funded = 0, admin = 1.
    /// @param state Packed state lane plus optional group byte.
    /// @param input Packed input lane plus optional group byte.
    /// @param output Packed output lane plus optional group byte.
    /// @param funded Whether the endpoint accepts nonzero native value.
    /// @param admin Whether the endpoint is restricted to the admin account.
    /// @return value Packed endpoint descriptor as an integer.
    function pack(
        bytes9 state,
        bytes9 input,
        bytes9 output,
        bool funded,
        bool admin
    ) private pure returns (uint value) {
        value |= uint(uint72(state)) << Lane.State;
        value |= uint(uint72(input)) << Lane.Input;
        value |= uint(uint72(output)) << Lane.Output;
        value |= uint(funded ? 1 : 0) << 32;
        value |= uint(admin ? 1 : 0) << 33;
    }

    /// @dev Return a lane's effective group size, defaulting non-empty lanes to one.
    /// @param descriptor Packed endpoint descriptor.
    /// @param shift Bit offset of the lane to inspect.
    /// @return size Effective group size, or zero when the lane is absent.
    function laneGroup(bytes32 descriptor, uint shift) private pure returns (uint8 size) {
        uint72 lane = uint72(uint(descriptor) >> shift);
        if (lane == 0) return 0;

        size = uint8(lane);
        if (size == 0) size = 1;
    }

    /// @dev Open a descriptor lane and return its effective group and output counts.
    /// An absent lane inherits `expected`; a present lane must match it when nonzero.
    /// @param source Block stream to open for the requested lane.
    /// @param descriptor Packed endpoint descriptor.
    /// @param shift Bit offset of the lane to open.
    /// @param expected Required group count, or zero to accept the lane's count.
    /// @return cur Cursor scoped to the lane's first block run.
    /// @return groups Number of lane groups in `cur`, or `expected` for an absent lane.
    /// @return outputs Number of output blocks implied by `groups` and the descriptor output lane.
    function openLane(
        bytes calldata source,
        bytes32 descriptor,
        uint shift,
        uint expected
    ) internal pure returns (Cur memory cur, uint groups, uint outputs) {
        (cur, groups) = Cursors.init(source, laneGroup(descriptor, shift));
        if (groups == 0) groups = expected;
        else if (expected != 0 && groups != expected) revert Cursors.BadRatio();
        outputs = groups * laneGroup(descriptor, Lane.Output);
    }

    /// @notice Open an endpoint state stream and return the expected output block count.
    /// @param source State block stream to open.
    /// @param descriptor Packed endpoint descriptor.
    /// @return state Cursor scoped to the state lane's first block run.
    /// @return outputs Number of output blocks implied by the state group count.
    function openState(
        bytes calldata source,
        bytes32 descriptor
    ) internal pure returns (Cur memory state, uint outputs) {
        (state, , outputs) = openLane(source, descriptor, Lane.State, 0);
    }

    /// @notice Open an endpoint input stream and return the expected output block count.
    /// @param source Input block stream to open.
    /// @param descriptor Packed endpoint descriptor.
    /// @return input Cursor scoped to the input lane's first block run.
    /// @return outputs Number of output blocks implied by the input group count.
    function openInput(
        bytes calldata source,
        bytes32 descriptor
    ) internal pure returns (Cur memory input, uint outputs) {
        (input, , outputs) = openLane(source, descriptor, Lane.Input, 0);
    }

    /// @notice Return an 8-byte lane value for a generic LIST containing `item`.
    /// @param item Block key expected inside each LIST payload.
    /// @return Packed lane key `[Keys.List][item]`.
    function many(bytes4 item) internal pure returns (bytes8) {
        return bytes8(bytes.concat(Keys.List, item));
    }

    /// @notice Append an explicit group size to an 8-byte lane value.
    /// @param value Packed lane key `[key][item]`.
    /// @param size Explicit per-operation group size for the lane.
    /// @return Packed lane key plus group byte.
    function group(bytes8 value, uint8 size) internal pure returns (bytes9) {
        return bytes9(bytes.concat(value, bytes1(size)));
    }

    /// @notice Publish a context-local block schema and return its key.
    /// @param key Context-local key value.
    /// @param body Schema DSL string describing the block payload body.
    /// @return The context-local block key.
    function schema(uint32 key, string memory body) internal returns (bytes4) {
        return schema(key, body, bytes32(0));
    }

    /// @notice Publish a named context-local block schema and return its key.
    /// @param key Context-local key value.
    /// @param body Schema DSL string describing the block payload body.
    /// @param name Schema alias name, or zero for unnamed schemas.
    /// @return The context-local block key.
    function schema(uint32 key, string memory body, bytes32 name) internal returns (bytes4) {
        bytes4 k = bytes4(key);
        emit Schema(host, k, body, name);
        return k;
    }

    /// @notice Create and publish endpoint metadata with a default label.
    /// @param id Endpoint node ID.
    /// @param name Default human-readable endpoint label.
    /// @param state Packed state lane plus optional group byte.
    /// @param input Packed input lane plus optional group byte.
    /// @param output Packed output lane plus optional group byte.
    /// @param funded Whether the endpoint accepts nonzero native value.
    /// @param admin Whether the endpoint is restricted to the admin account.
    /// @return descriptor Packed endpoint lane metadata and flags.
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
