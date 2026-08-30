// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Blocks} from "./Blocks.sol";
import {Buffers} from "./Buffers.sol";
import {Sizes, Specs} from "./Specs.sol";
import {Lanes} from "../utils/Lanes.sol";
import {Flags} from "../utils/Flags.sol";

/// @title Descriptors
/// @notice Packing and lane metadata helpers for endpoint descriptors.
library Descriptors {
    /// @notice Create a descriptor from endpoint lane specifications and flags.
    /// @dev Layout: `[state key:4][stride:1]`
    /// `[input key:4][stride:1]`
    /// `[output key:4][min:4][max:4][hint:3][stride:1]`
    /// `[reserved:5]`
    /// `[flags:1]`. Flag bits: funded = 0, admin = 1, handoff = 7;
    /// bit 6 is reserved for endpoint-defined custom behavior.
    /// @dev TODO: Add per-lane cardinality metadata so off-chain consumers can
    /// distinguish exactly-one lanes from batches. Command decoding must remain
    /// the runtime source of truth; this metadata should not restore eager scans.
    /// @param state State lane specification.
    /// @param input Direct input lane specification.
    /// @param output Output writer specification.
    /// @param flags Endpoint behavior flags.
    /// @return descriptor Packed endpoint descriptor.
    function create(
        uint state,
        uint input,
        uint output,
        uint8 flags
    ) internal pure returns (uint descriptor) {
        output = Specs.normalize(output);
        descriptor |= uint(Specs.lane(state)) << 216;
        descriptor |= uint(Specs.lane(input)) << 176;
        descriptor |= (output >> 128) << 48;
        descriptor |= flags;
    }

    /// @dev Wrap endpoint input with its descriptor stride and lane tag.
    function inputCursor(bytes calldata source, uint descriptor) private pure returns (uint cur) {
        uint tag = Lanes.Input;
        assembly ("memory-safe") {
            cur := or(
                or(or(shl(32, source.offset), shl(64, source.length)), shl(96, byte(9, descriptor))),
                shl(120, tag)
            )
        }
    }

    /// @dev Wrap command state with its descriptor stride and lane tag.
    function stateCursor(bytes calldata source, uint descriptor) private pure returns (uint cur) {
        uint tag = Lanes.State;
        assembly ("memory-safe") {
            cur := or(
                or(or(shl(32, source.offset), shl(64, source.length)), shl(96, byte(4, descriptor))),
                shl(120, tag)
            )
        }
    }

    /// @dev Initialize the output writer from the selected lower decoder lane.
    /// The run count is an allocation hint only; decoding and finalization validate the source.
    function writerCursor(uint decoders, uint descriptor) private pure returns (uint writer) {
        uint outputStride = uint8(descriptor >> 48);
        if (outputStride == 0) return 0;

        uint decoderStride = uint8(decoders >> 96);
        uint count;
        if (decoderStride != 0) {
            uint abs = uint32(decoders >> 32);
            uint end = abs + uint32(decoders >> 64);
            uint laneShift = uint8(decoders >> 120) == Lanes.Input ? 176 : 216;
            count = Blocks.runCount(
                abs,
                end,
                bytes4(uint32(descriptor >> (laneShift + 8)))
            ) / decoderStride * outputStride;
        }

        uint capacity = count * (Sizes.Header + uint24(descriptor >> 56));
        writer = Buffers.cursor(capacity, uint8(outputStride), 0);
    }

    /// @notice Open descriptor-backed input and output cursors.
    function openInput(
        uint descriptor,
        bytes calldata input
    ) internal pure returns (uint decoders, uint writer) {
        decoders = inputCursor(input, descriptor);
        writer = writerCursor(decoders, descriptor);
    }

    /// @notice Open descriptor-backed state and output cursors.
    function openState(
        uint descriptor,
        bytes calldata state
    ) internal pure returns (uint decoders, uint writer) {
        decoders = stateCursor(state, descriptor);
        writer = writerCursor(decoders, descriptor);
    }

    /// @notice Open paired descriptor-backed state, input, and output cursors.
    /// @dev Input remains low when present; otherwise state becomes the active lower lane.
    function open(
        uint descriptor,
        bytes calldata state,
        bytes calldata input
    ) internal pure returns (uint decoders, uint writer) {
        decoders = inputCursor(input, descriptor) | (stateCursor(state, descriptor) << 128);
        if (uint8(decoders >> 96) == 0) {
            decoders = (decoders << 128) | (decoders >> 128);
        }
        writer = writerCursor(decoders, descriptor);
    }
}
