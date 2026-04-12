// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { HostAmount, Tx, Keys } from "./Schema.sol";
import { Cursors } from "./Cursors.sol";

/// @notice Reference to a single block inside a `bytes memory` buffer.
/// Positions are byte offsets within the buffer (not absolute memory addresses).
struct MemRef {
    /// @dev Block type identifier read from the 4-byte header key.
    bytes4 key;
    /// @dev Payload start offset (byte immediately after the 8-byte header).
    uint i;
    /// @dev Payload end offset (equals `i + payloadLen`).
    uint end;
}

/// @title Mem
/// @notice Memory block stream parser for the rootzero protocol.
/// Mirrors the calldata-oriented `Cursors` API but operates on `bytes memory`
/// buffers, using `mcopy`/`mload` assembly instead of `msg.data` slices.
library Mem {
    /// @notice Parse a block header at offset `i` within `source`.
    /// Returns an empty sentinel `MemRef` (all zeros) when `i` is at end-of-data.
    /// @param source In-memory block stream buffer.
    /// @param i Byte offset of the block header within `source`.
    /// @return ref Parsed block reference with key, payload start, and payload end.
    function from(bytes memory source, uint i) internal pure returns (MemRef memory ref) {
        uint eod = source.length;
        if (i == eod) return MemRef(bytes4(0), i, i);
        if (i > eod) revert Cursors.MalformedBlocks();

        unchecked {
            ref.i = i + 8;
        }
        if (ref.i > eod) revert Cursors.MalformedBlocks();

        // Read the 8-byte block header (key + payloadLen) in one mload.
        bytes32 w;
        assembly ("memory-safe") {
            w := mload(add(add(source, 0x20), i))
        }

        ref.key = bytes4(w);
        ref.end = ref.i + uint32(bytes4(w << 32));
        if (ref.end > eod) revert Cursors.MalformedBlocks();
    }

    /// @notice Extract a byte range `[start, end)` from `source` into a new buffer.
    /// @param source Source buffer.
    /// @param start Inclusive start offset.
    /// @param end Exclusive end offset.
    /// @return out Copied slice as a new `bytes` value.
    function slice(bytes memory source, uint start, uint end) internal pure returns (bytes memory out) {
        if (end < start || end > source.length) revert Cursors.MalformedBlocks();
        uint len = end - start;
        out = new bytes(len);
        if (len == 0) return out;

        assembly ("memory-safe") {
            mcopy(add(out, 0x20), add(add(source, 0x20), start), len)
        }
    }

    /// @notice Count consecutive blocks of `key` starting at offset `i`.
    /// @param source Source buffer.
    /// @param i Starting byte offset.
    /// @param key Block type to count.
    /// @return total Number of consecutive matching blocks.
    /// @return cursor Byte offset immediately after the last counted block.
    function count(bytes memory source, uint i, bytes4 key) internal pure returns (uint total, uint cursor) {
        cursor = i;
        while (cursor < source.length) {
            MemRef memory ref = from(source, cursor);
            if (ref.key != key) break;
            unchecked {
                ++total;
            }
            cursor = ref.end;
        }
    }

    /// @notice Scan forward from `i` up to `limit` for the first block matching `key`.
    /// Returns an empty sentinel `MemRef` (key == 0, i == end == limit) if not found.
    /// @param source Source buffer.
    /// @param i Starting byte offset.
    /// @param limit Exclusive upper bound for the search (must be ≤ `source.length`).
    /// @param key Block type to find.
    /// @return ref Reference to the first matching block, or the sentinel if absent.
    function find(bytes memory source, uint i, uint limit, bytes4 key) internal pure returns (MemRef memory ref) {
        if (limit > source.length) revert Cursors.MalformedBlocks();
        while (i < limit) {
            ref = from(source, i);
            if (ref.end > limit) revert Cursors.MalformedBlocks();
            if (ref.key == key) return ref;
            i = ref.end;
        }

        return MemRef(bytes4(0), limit, limit);
    }

    /// @notice Assert that `ref` points to a block of the expected type.
    /// @param ref Block reference to validate.
    /// @param key Expected block type key.
    function ensure(MemRef memory ref, bytes4 key) internal pure {
        if (key == 0 || key != ref.key) revert Cursors.InvalidBlock();
    }

    /// @notice Assert that `ref` points to a block of the expected type with exact payload length.
    /// @param ref Block reference to validate.
    /// @param key Expected block type key.
    /// @param len Expected payload byte length.
    function ensure(MemRef memory ref, bytes4 key, uint len) internal pure {
        if (key == 0 || key != ref.key || len != (ref.end - ref.i)) revert Cursors.InvalidBlock();
    }

    /// @notice Assert that `ref` points to a block of the expected type within a length range.
    /// @param ref Block reference to validate.
    /// @param key Expected block type key.
    /// @param min Minimum payload length (inclusive).
    /// @param max Maximum payload length (inclusive); 0 means unbounded.
    function ensure(MemRef memory ref, bytes4 key, uint min, uint max) internal pure {
        uint len = ref.end - ref.i;
        if (key == 0 || key != ref.key || len < min || (max != 0 && len > max)) revert Cursors.InvalidBlock();
    }

    /// @notice Decode a BALANCE block payload from `source` using the given reference.
    /// @param ref Block reference; must point to a BALANCE block with exactly 96 payload bytes.
    /// @param source Buffer containing the block.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Token amount.
    function unpackBalance(
        MemRef memory ref,
        bytes memory source
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        ensure(ref, Keys.Balance, 96);
        uint i = ref.i;

        // Read three contiguous 32-byte words from the payload.
        assembly ("memory-safe") {
            let p := add(add(source, 0x20), i)
            asset := mload(p)
            meta := mload(add(p, 0x20))
            amount := mload(add(p, 0x40))
        }
    }

    /// @notice Decode a CUSTODY block payload from `source` into a `HostAmount` struct.
    /// @param ref Block reference; must point to a CUSTODY block with exactly 128 payload bytes.
    /// @param source Buffer containing the block.
    /// @return value Decoded host, asset, meta, and amount.
    function toCustodyValue(
        MemRef memory ref,
        bytes memory source
    ) internal pure returns (HostAmount memory value) {
        ensure(ref, Keys.Custody, 128);
        uint i = ref.i;

        // Copy four 32-byte payload words directly into the struct memory slots.
        assembly ("memory-safe") {
            let p := add(add(source, 0x20), i)
            mstore(value, mload(p))
            mstore(add(value, 0x20), mload(add(p, 0x20)))
            mstore(add(value, 0x40), mload(add(p, 0x40)))
            mstore(add(value, 0x60), mload(add(p, 0x60)))
        }
    }

    /// @notice Decode a TRANSACTION block payload from `source` into a `Tx` struct.
    /// @param ref Block reference; must point to a TRANSACTION block with exactly 160 payload bytes.
    /// @param source Buffer containing the block.
    /// @return value Decoded from, to, asset, meta, and amount.
    function toTxValue(MemRef memory ref, bytes memory source) internal pure returns (Tx memory value) {
        ensure(ref, Keys.Transaction, 160);
        uint i = ref.i;

        // Copy five 32-byte payload words directly into the struct memory slots.
        assembly ("memory-safe") {
            let p := add(add(source, 0x20), i)
            mstore(value, mload(p))
            mstore(add(value, 0x20), mload(add(p, 0x20)))
            mstore(add(value, 0x40), mload(add(p, 0x40)))
            mstore(add(value, 0x60), mload(add(p, 0x60)))
            mstore(add(value, 0x80), mload(add(p, 0x80)))
        }
    }
}
