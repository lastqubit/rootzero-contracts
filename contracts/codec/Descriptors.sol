// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Specs} from "./Specs.sol";
import {Lanes} from "../utils/Lanes.sol";

/// @title Descriptors
/// @notice Packing and lane metadata helpers for endpoint descriptors.
library Descriptors {
    /// @dev The requested lane is not part of an endpoint descriptor.
    error InvalidLane();

    /// @dev Endpoint accepts nonzero native value.
    uint8 internal constant Funded = 1 << 0;
    /// @dev Endpoint is restricted to the admin account.
    uint8 internal constant Admin = 1 << 1;

    /// @notice Create a descriptor from endpoint lane specifications and flags.
    /// @dev Layout: `[state key:4][stride:1]`
    /// `[input key:4][item:4][stride:1]`
    /// `[output key:4][min:4][max:4][hint:3][stride:1]`
    /// `[transactions:1]`
    /// `[flags:1]`. Flag bits: funded = 0, admin = 1.
    /// @param state State lane specification.
    /// @param input Input lane specification, optionally wrapped in a container.
    /// @param output Output writer specification.
    /// @param transactions Transactions produced per batch.
    /// @param flags Endpoint behavior flags.
    /// @return descriptor Packed endpoint descriptor.
    function create(
        uint state,
        uint input,
        uint output,
        uint8 transactions,
        uint8 flags
    ) internal pure returns (uint descriptor) {
        state = Specs.normalize(state, true);
        input = Specs.normalize(input, false);
        output = Specs.normalize(output, true);
        descriptor = pack(state, input, output, transactions, flags);
    }

    /// @dev Pack normalized endpoint specs and flags into a descriptor.
    /// @param state Normalized direct state specification.
    /// @param input Normalized input specification.
    /// @param output Normalized direct output specification.
    /// @param transactions Transactions produced per batch.
    /// @param flags Endpoint behavior flags.
    /// @return descriptor Packed endpoint descriptor.
    function pack(
        uint state,
        uint input,
        uint output,
        uint8 transactions,
        uint8 flags
    ) private pure returns (uint descriptor) {
        (bytes4 outer, bytes4 child) = Specs.keys(input);

        descriptor |= uint(uint32(Specs.key(state))) << 224;
        descriptor |= uint(Specs.stride(state)) << 216;
        descriptor |= uint(uint32(outer)) << 184;
        descriptor |= uint(uint32(child)) << 152;
        descriptor |= uint(Specs.stride(input)) << 144;
        descriptor |= (output >> 128) << 16;
        descriptor |= uint(transactions) << 8;
        descriptor |= flags;
    }

    /// @notice Return whether a descriptor contains `flag`.
    /// @param descriptor Packed endpoint descriptor.
    /// @param flag Flag bit or bit set to test.
    /// @return Whether any requested flag bit is present.
    function flagged(uint descriptor, uint8 flag) internal pure returns (bool) {
        return uint8(descriptor) & flag != 0;
    }

    /// @notice Return the effective per-batch stride for `lane`.
    /// @dev Descriptor creation resolves implicit spec strides, so every lane
    /// stores its effective value directly.
    /// @param descriptor Packed endpoint descriptor.
    /// @param lane Lane identifier from `Lanes`.
    /// @return Effective blocks per batch for the lane.
    function stride(uint descriptor, uint8 lane) internal pure returns (uint8) {
        if (lane == Lanes.State) return uint8(descriptor >> 216);
        if (lane == Lanes.Input) return uint8(descriptor >> 144);
        if (lane == Lanes.Output) return uint8(descriptor >> 16);
        if (lane == Lanes.Transactions) return uint8(descriptor >> 8);
        revert InvalidLane();
    }

    /// @notice Return the effective block key for `lane`.
    /// @dev Input returns its outer key. Transaction blocks have a fixed
    /// protocol key that is not stored in the descriptor.
    /// @param descriptor Packed endpoint descriptor.
    /// @param lane Lane identifier from `Lanes`.
    /// @return Effective outer block key for the lane.
    function key(uint descriptor, uint8 lane) internal pure returns (bytes4) {
        if (lane == Lanes.State) return bytes4(uint32(descriptor >> 224));
        if (lane == Lanes.Input) return bytes4(uint32(descriptor >> 184));
        if (lane == Lanes.Output) return bytes4(uint32(descriptor >> 112));
        if (lane == Lanes.Transactions) return Specs.key(Specs.Transaction);
        revert InvalidLane();
    }

    /// @notice Return the buffer configuration for descriptor writer `lane`.
    /// @param descriptor Packed endpoint descriptor.
    /// @param lane Output or transaction writer lane.
    /// @param groups Number of execution batches to allocate for.
    /// @return capacity Initial logical byte capacity.
    /// @return growable Whether the writer may grow beyond that capacity.
    function allocation(uint descriptor, uint8 lane, uint groups) internal pure returns (uint capacity, bool growable) {
        if (lane == Lanes.Output) {
            uint spec = uint(uint128(descriptor >> 16)) << 128;
            return Specs.allocation(spec, groups);
        }
        if (lane == Lanes.Transactions) {
            uint count = groups * stride(descriptor, lane);
            return Specs.allocation(Specs.Transaction, count);
        }

        revert InvalidLane();
    }
}
