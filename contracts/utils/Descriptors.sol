// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Specs} from "../codec/Specs.sol";

/// @title Descriptors
/// @notice Packing and lane metadata helpers for endpoint descriptors.
library Descriptors {
    /// @dev State and output lanes cannot be wrapped in container blocks.
    error InvalidContainer();

    /// @dev Descriptor shift for the state lane.
    uint internal constant State = 216;
    /// @dev Descriptor shift for the input lane.
    uint internal constant Input = 144;
    /// @dev Descriptor shift for the output lane.
    uint internal constant Output = 8;

    /// @notice Pack endpoint lanes and flags into a descriptor.
    /// @dev Layout: `[state key:4][group:1]`
    /// `[input key:4][item:4][group:1]`
    /// `[output key:4][min:4][max:4][hint:4][group:1]`
    /// `[flags:1]`. Flag bits: funded = 0, admin = 1.
    function pack(
        uint stateSpec,
        uint inputSpec,
        uint outputSpec,
        bool funded,
        bool admin
    ) internal pure returns (uint descriptor) {
        if (Specs.container(stateSpec) != bytes4(0) || Specs.container(outputSpec) != bytes4(0)) {
            revert InvalidContainer();
        }

        descriptor |= ((uint(uint32(Specs.key(stateSpec))) << 8) | uint8(stateSpec >> 120)) << State;
        descriptor |= uint(encodeInput(inputSpec)) << Input;
        descriptor |= (outputSpec >> 120) << Output;
        descriptor |= uint(funded ? 1 : 0);
        descriptor |= uint(admin ? 1 : 0) << 1;
    }

    /// @dev Derive `[key:4][item:4][group:1]` from an input spec.
    function encodeInput(uint spec) private pure returns (uint72 value) {
        bytes4 key = Specs.key(spec);
        bytes4 container = Specs.container(spec);
        bytes4 item;

        if (container != bytes4(0)) {
            item = key;
            key = container;
        }

        value = (uint72(uint32(key)) << 40) | (uint72(uint32(item)) << 8) | uint72(uint8(spec >> 120));
    }

    /// @notice Return a lane's effective group size.
    /// @dev A non-empty lane with an encoded group of zero defaults to one.
    /// @return size Effective group size, or zero when the lane is absent.
    function group(uint descriptor, uint shift) internal pure returns (uint8 size) {
        size = uint8(descriptor >> shift);
        uint keyShift = shift == State ? State + 8 : shift == Input ? Input + 40 : Output + 104;
        if (size == 0 && uint32(descriptor >> keyShift) != 0) size = 1;
    }

    /// @notice Decode state-lane metadata.
    function state(uint descriptor) internal pure returns (bytes4 key, uint8 groupSize) {
        uint40 value = uint40(descriptor >> State);
        if (value == 0) return (0, 0);

        uint8 size = uint8(value);
        key = bytes4(uint32(value >> 8));
        groupSize = size == 0 ? 1 : size;
    }

    /// @notice Decode input-lane metadata.
    function input(uint descriptor) internal pure returns (bytes4 key, bytes4 item, uint8 groupSize) {
        uint72 value = uint72(descriptor >> Input);
        if (value == 0) return (0, 0, 0);

        uint8 size = uint8(value);
        key = bytes4(uint32(value >> 40));
        item = bytes4(uint32(value >> 8));
        groupSize = size == 0 ? 1 : size;
    }

    /// @notice Decode the output lane into a writer-ready spec.
    /// @dev The returned spec is left aligned in a full word and retains its encoded group.
    /// Its container and reserved fields are cleared. Use `Specs.group` for its effective group.
    function output(uint descriptor) internal pure returns (uint spec) {
        spec = uint(uint136(descriptor >> Output)) << 120;
    }

    /// @notice Return the output block count implied by `groups`.
    function outputs(uint descriptor, uint groups) internal pure returns (uint) {
        return groups * Specs.group(output(descriptor));
    }
}
