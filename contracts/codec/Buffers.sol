// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

/// @title Buffers
/// @notice Allocation and finalization helpers for mutable memory byte buffers.
library Buffers {
    uint private constant FIELD_MASK = type(uint32).max;
    uint private constant END_SHIFT = 32;
    uint private constant GROWABLE_FLAG = uint(1) << 64;

    /// @dev The requested logical length exceeds the physical buffer length.
    error BufferOverflow();

    /// @notice Initialize packed buffer metadata at write position zero.
    function init(uint end, bool growable) internal pure returns (uint meta) {
        meta = encode(0, end, growable);
    }

    /// @dev Pack the write position, logical end, and growth policy into one word.
    function encode(uint i, uint end, bool growable) private pure returns (uint meta) {
        if (i > FIELD_MASK || end > FIELD_MASK) revert BufferOverflow();
        meta = i | (end << END_SHIFT) | (growable ? GROWABLE_FLAG : 0);
    }

    /// @notice Decode packed buffer metadata.
    function decode(uint meta) internal pure returns (uint i, uint end, bool growable) {
        i = uint32(meta);
        end = uint32(meta >> END_SHIFT);
        growable = meta & GROWABLE_FLAG != 0;
    }

    /// @notice Reserve relative write space and return updated packed buffer metadata.
    /// @param meta Current packed buffer metadata.
    /// @param buffer Current backing buffer.
    /// @param advance Logical number of bytes appended.
    /// @param touch Physical number of bytes the write may touch.
    /// @return updated Updated packed buffer metadata.
    /// @return dst Original or resized backing buffer.
    /// @return i Original write offset.
    function reserve(
        uint meta,
        bytes memory buffer,
        uint advance,
        uint touch
    ) internal pure returns (uint updated, bytes memory dst, uint i) {
        uint end;
        bool growable;
        (i, end, growable) = decode(meta);
        uint position = i + advance;
        uint required = i + (advance > touch ? advance : touch);
        dst = buffer;

        if (growable) {
            if (required > end) {
                end = end == 0 ? 64 : end * 2;
                while (end < required) {
                    end *= 2;
                }
                dst = resize(dst, i, end);
            }
        } else if (position > end) revert BufferOverflow();

        if (dst.length == 0) {
            dst = alloc(end);
        } else if (required > dst.length) revert BufferOverflow();

        updated = encode(position, end, growable);
    }

    /// @notice Allocate a buffer with `capacity` logical bytes and trailing write space.
    /// @dev The returned byte-array length is its padded physical capacity. Callers must
    /// track the logical capacity separately and trim the buffer before returning it.
    function alloc(uint capacity) internal pure returns (bytes memory buffer) {
        uint padded = ((capacity + 31) & ~uint(31)) + 32;
        buffer = new bytes(padded);
    }

    /// @notice Allocate a buffer with `capacity` and copy its written prefix.
    /// @dev Performs no bounds checks; the caller must ensure `written <= buffer.length`.
    /// @param buffer Current buffer.
    /// @param written Number of leading bytes to copy.
    /// @param capacity Requested capacity of the new buffer.
    /// @return resized Newly allocated buffer containing the written prefix.
    function resize(
        bytes memory buffer,
        uint written,
        uint capacity
    ) internal pure returns (bytes memory resized) {
        resized = alloc(capacity);
        assembly ("memory-safe") {
            mcopy(add(resized, 0x20), add(buffer, 0x20), written)
        }
    }

    /// @notice Grow `buffer` geometrically when `required` exceeds its current capacity.
    /// @dev Only the first `written` bytes are copied into a newly allocated buffer.
    /// @param buffer Current buffer.
    /// @param written Number of meaningful bytes to preserve.
    /// @param required Minimum required capacity.
    /// @return The original buffer when large enough, otherwise a larger buffer.
    function grow(bytes memory buffer, uint written, uint required) internal pure returns (bytes memory) {
        uint capacity = buffer.length;
        if (written > capacity) revert BufferOverflow();
        if (required <= capacity) return buffer;

        capacity = capacity == 0 ? 64 : capacity * 2;
        while (capacity < required) {
            capacity *= 2;
        }

        return resize(buffer, written, capacity);
    }

    /// @notice Write raw bytes at byte offset `i`.
    function write(bytes memory buffer, uint i, bytes memory value) internal pure returns (uint next) {
        next = i + value.length;
        if (next > buffer.length) revert BufferOverflow();
        assembly ("memory-safe") {
            mcopy(add(add(buffer, 0x20), i), add(value, 0x20), mload(value))
        }
    }

    /// @notice Write one complete raw word at byte offset `i`.
    function write32(bytes memory buffer, uint i, bytes32 value) internal pure {
        if (i + 32 > buffer.length) revert BufferOverflow();
        assembly ("memory-safe") {
            mstore(add(add(buffer, 0x20), i), value)
        }
    }

    /// @notice Write two complete raw words at byte offset `i`.
    function write64(
        bytes memory buffer,
        uint i,
        bytes32 a,
        bytes32 b
    ) internal pure {
        if (i + 64 > buffer.length) revert BufferOverflow();
        assembly ("memory-safe") {
            let p := add(add(buffer, 0x20), i)
            mstore(p, a)
            mstore(add(p, 0x20), b)
        }
    }

    /// @notice Write three complete raw words at byte offset `i`.
    function write96(
        bytes memory buffer,
        uint i,
        bytes32 a,
        bytes32 b,
        bytes32 c
    ) internal pure {
        if (i + 96 > buffer.length) revert BufferOverflow();
        assembly ("memory-safe") {
            let p := add(add(buffer, 0x20), i)
            mstore(p, a)
            mstore(add(p, 0x20), b)
            mstore(add(p, 0x40), c)
        }
    }

    /// @notice Set a buffer's visible length to the number of bytes actually written.
    /// @param buffer Buffer to trim in place.
    /// @param len Logical byte length to expose.
    /// @return The same buffer with its length set to `len`.
    function trim(bytes memory buffer, uint len) internal pure returns (bytes memory) {
        if (len > buffer.length) revert BufferOverflow();
        assembly ("memory-safe") {
            mstore(buffer, len)
        }
        return buffer;
    }
}
