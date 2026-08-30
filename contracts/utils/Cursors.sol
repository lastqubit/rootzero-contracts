// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {MissingCursor, OutOfBounds, UnexpectedPosition, ValueOverflow} from "./Errors.sol";

/// @notice Mutable memory wrapper around a packed cursor.
/// @dev A second tagged cursor may occupy the upper 128-bit lane of `state`.
/// Cursor operations target the lower lane; `Cursors.select` swaps the requested
/// tagged cursor into that position.
struct Cur {
    uint state;
}

/// @title Cursors
/// @notice Packed cursor state and navigation for byte regions.
/// @dev Each 128-bit cursor uses the following layout:
/// bits   0-31    i
/// bits  32-63    offset
/// bits  64-95    len
/// bits  96-103   stride (optional blocks per group)
/// bits 104-111   reserved
/// bits 112-119   flags (consumer-defined)
/// bits 120-127   tag
///
/// A cursor is one 128-bit value with this layout. A pair is a 256-bit value
/// containing a lower cursor in bits 0-127 and an optional higher cursor in
/// bits 128-255. The lower cursor is the active cursor: navigation and
/// inspection operations target it, and `select` swaps a requested tagged
/// cursor into that position while preserving the pair.
///
/// Cursor navigation assumes packed cursor inputs satisfy `i <= len`.
/// Constructors and composition helpers establish this invariant, and navigation
/// helpers preserve it. Manually constructing or modifying packed cursor words
/// may cause arithmetic panics instead of cursor-specific errors.
///
/// The zero word represents an absent cursor.
library Cursors {
    // Creation and sources

    /// @notice Create a cursor positioned at its beginning.
    /// @param offset Absolute source or buffer offset.
    /// @param len Logical byte length.
    /// @param stride Optional blocks per group associated with the region.
    /// @param flags Consumer-defined flags.
    /// @param tag Cursor identity tag.
    /// @return cur Packed cursor.
    function create(uint offset, uint len, uint8 stride, uint8 flags, uint8 tag) internal pure returns (uint cur) {
        if (offset > type(uint32).max || len > type(uint32).max) {
            revert ValueOverflow();
        }
        cur = (offset << 32) | (len << 64) | (uint(stride) << 96) | (uint(flags) << 112) | (uint(tag) << 120);
    }

    /// @notice Return the absolute calldata position where `source` begins.
    /// @param source Calldata slice whose base is requested.
    /// @return abs Absolute calldata position.
    function base(bytes calldata source) internal pure returns (uint abs) {
        assembly ("memory-safe") {
            abs := source.offset
        }
    }

    /// @notice Return the absolute calldata start and exclusive end of `source`.
    /// @param source Calldata slice whose bounds are requested.
    /// @return abs Absolute start position.
    /// @return end Absolute exclusive end position.
    function bounds(bytes calldata source) internal pure returns (uint abs, uint end) {
        assembly ("memory-safe") {
            abs := source.offset
            end := add(abs, source.length)
        }
    }

    /// @notice Return the absolute start and exclusive end of the lower cursor frame.
    /// @dev Ignores the cursor's current relative position and any upper cursor.
    /// @param cur Packed cursor or cursor pair whose active frame is inspected.
    /// @return abs Absolute frame start position.
    /// @return end Absolute exclusive frame end position.
    function bounds(uint cur) internal pure returns (uint abs, uint end) {
        abs = uint32(cur >> 32);
        end = abs + uint32(cur >> 64);
    }

    /// @notice Return the unread calldata region represented by the lower cursor.
    /// @dev DANGER: This trusts the packed cursor and does not validate the frame
    /// against `msg.data`. Assumes the cursor invariant `i <= len`; any upper
    /// cursor is ignored.
    /// @param cur Packed cursor or cursor pair whose unread region is returned.
    /// @return data Lower-cursor calldata from its current position through its end.
    function raw(uint cur) internal pure returns (bytes calldata data) {
        assembly ("memory-safe") {
            let i := and(cur, 0xffffffff)
            data.offset := add(and(shr(32, cur), 0xffffffff), i)
            data.length := sub(and(shr(64, cur), 0xffffffff), i)
        }
    }

    /// @notice Create an untagged cursor backed by a calldata slice.
    /// @param source Calldata slice represented by the cursor.
    /// @return cur Packed cursor positioned at the slice beginning.
    function wrap(bytes calldata source) internal pure returns (uint cur) {
        assembly ("memory-safe") {
            cur := or(shl(32, source.offset), shl(64, source.length))
        }
    }

    /// @notice Create a tagged cursor backed by a calldata slice.
    /// @param source Calldata slice represented by the cursor.
    /// @param tag Cursor identity tag.
    /// @return cur Packed cursor positioned at the slice beginning.
    function wrap(bytes calldata source, uint8 tag) internal pure returns (uint cur) {
        assembly ("memory-safe") {
            cur := or(or(shl(32, source.offset), shl(64, source.length)), shl(120, tag))
        }
    }

    // Inspection

    /// @notice Decode the positional fields from the lower cursor.
    /// @param cur Packed cursor or cursor pair.
    /// @return i Current relative position.
    /// @return offset Absolute base offset.
    /// @return len Logical byte length.
    function decode(uint cur) internal pure returns (uint i, uint offset, uint len) {
        i = uint32(cur);
        offset = uint32(cur >> 32);
        len = uint32(cur >> 64);
    }

    /// @notice Return the active cursor without its position.
    /// @dev Ignores the upper cursor when `cur` is a pair.
    /// @param cur Packed cursor or cursor pair.
    /// @return The lower cursor's offset, length, stride, flags, and tag.
    function frame(uint cur) internal pure returns (uint) {
        return uint128(cur) & ~uint(type(uint32).max);
    }

    /// @notice Return the absolute position of the lower cursor as `offset + i`.
    /// @dev Performs no bounds check.
    /// @param cur Packed cursor or cursor pair.
    /// @return Absolute current position.
    function absolute(uint cur) internal pure returns (uint) {
        return uint32(cur) + uint32(cur >> 32);
    }

    /// @notice Decode the optional stride, consumer flags, and identity tag.
    /// @param cur Packed cursor or cursor pair.
    /// @return stride Optional blocks per group.
    /// @return flags Consumer-defined flags.
    /// @return tag Cursor identity tag.
    function meta(uint cur) internal pure returns (uint8 stride, uint8 flags, uint8 tag) {
        stride = uint8(cur >> 96);
        flags = uint8(cur >> 112);
        tag = uint8(cur >> 120);
    }

    /// @notice Return whether both packed cursors remain at their initial positions.
    /// @param cur Packed cursor or cursor pair.
    /// @return Whether both lane positions are zero.
    function initial(uint cur) internal pure returns (bool) {
        return uint32(cur) == 0 && uint32(cur >> 128) == 0;
    }

    /// @notice Return whether the lower cursor's current position precedes its length.
    /// @param cur Packed cursor or cursor pair.
    /// @return Whether the lower cursor has bytes remaining.
    function more(uint cur) internal pure returns (bool) {
        return uint32(cur) < uint32(cur >> 64);
    }

    /// @notice Return whether either packed cursor has remaining bytes.
    /// @param cur Packed cursor or cursor pair.
    /// @return Whether either lane has bytes remaining.
    function any(uint cur) internal pure returns (bool) {
        return uint32(cur) < uint32(cur >> 64) || uint32(cur >> 128) < uint32(cur >> 192);
    }

    /// @notice Require the lower cursor to be positioned at `i`.
    /// @param cur Packed cursor or cursor pair.
    /// @param i Expected relative position.
    function expect(uint cur, uint i) internal pure {
        if (uint32(cur) != i) revert UnexpectedPosition();
    }

    /// @notice Require the lower cursor to be positioned at absolute position `abs`.
    /// @param cur Packed cursor or cursor pair.
    /// @param abs Expected absolute position.
    function expectAbs(uint cur, uint abs) internal pure {
        if (uint32(cur) + uint32(cur >> 32) != abs) revert UnexpectedPosition();
    }

    /// @notice Return whether the lower cursor contains `flag`.
    /// @param cur Packed cursor or cursor pair.
    /// @param flag Consumer-defined flag bit or bit set.
    /// @return Whether any requested flag bit is present.
    function flagged(uint cur, uint8 flag) internal pure returns (bool) {
        return uint8(cur >> 112) & flag != 0;
    }

    // Navigation

    /// @notice Move the lower cursor forward to `i`.
    /// @param cur Packed cursor or cursor pair.
    /// @param i New relative position; must not move backward.
    /// @return updated Cursor with the new lower position.
    function seek(uint cur, uint i) internal pure returns (uint updated) {
        uint current = uint32(cur);
        uint len = uint32(cur >> 64);
        if (i < current || i > len) revert OutOfBounds();
        updated = (cur & ~uint(type(uint32).max)) | i;
    }

    /// @notice Replace the lower cursor's position using an absolute position.
    /// @param cur Packed cursor or cursor pair.
    /// @param abs New absolute position.
    /// @return updated Cursor with the corresponding relative position.
    function seekAbs(uint cur, uint abs) internal pure returns (uint updated) {
        uint offset = uint32(cur >> 32);
        if (abs < offset) revert OutOfBounds();
        uint i = abs - offset;
        if (i < uint32(cur) || i > uint32(cur >> 64)) revert OutOfBounds();
        updated = (cur & ~uint(type(uint32).max)) | i;
    }

    /// @notice Advance the current position of the lower cursor.
    /// @dev Assumes `cur` satisfies the cursor invariant `i <= len`.
    /// @param cur Packed cursor or cursor pair.
    /// @param amount Number of bytes to advance.
    /// @return updated Cursor advanced by `amount`.
    function advance(uint cur, uint amount) internal pure returns (uint updated) {
        uint i = uint32(cur);
        uint len = uint32(cur >> 64);
        if (amount > len - i) revert OutOfBounds();
        updated = cur + amount;
    }

    /// @notice Replace the logical length of the lower cursor.
    /// @dev A cursor cannot be resized below its current position.
    /// @param cur Packed cursor or cursor pair.
    /// @param len New logical length.
    /// @return updated Cursor with the replaced length.
    function resize(uint cur, uint len) internal pure returns (uint updated) {
        if (len > type(uint32).max) revert ValueOverflow();
        if (uint32(cur) > len) revert OutOfBounds();
        updated = (cur & ~(uint(type(uint32).max) << 64)) | (len << 64);
    }

    /// @notice Create a child cursor over `[start, end)` within the lower cursor.
    /// @dev The child starts at position zero, has no recorded count, and uses the
    /// supplied tag. Any higher cursor is omitted. Assumes `cur` satisfies the
    /// cursor invariant `i <= len`.
    /// @param cur Parent cursor or cursor pair.
    /// @param start Child start relative to the parent base.
    /// @param end Child exclusive end relative to the parent base.
    /// @param tag Child identity tag.
    /// @return child Packed child cursor.
    function slice(uint cur, uint start, uint end, uint8 tag) internal pure returns (uint child) {
        uint offset = uint32(cur >> 32);
        uint len = uint32(cur >> 64);
        if (start > end || end > len) revert OutOfBounds();
        uint childOffset = offset + start;
        if (childOffset > type(uint32).max) revert ValueOverflow();
        child = (childOffset << 32) | ((end - start) << 64) | (uint(tag) << 120);
    }

    // Selection

    /// @notice Swap the lower and higher cursors.
    /// @param cur Packed cursor pair.
    /// @return updated Pair with its lanes exchanged.
    function swap(uint cur) internal pure returns (uint updated) {
        updated = (cur << 128) | (cur >> 128);
    }

    /// @notice Return whether either packed cursor has the nonzero `expected` tag.
    /// @dev Tag zero denotes an untagged cursor and is never matched by this helper.
    /// @param cur Packed cursor or cursor pair.
    /// @param expected Nonzero identity tag to find.
    /// @return Whether either lane has the requested tag.
    function contains(uint cur, uint8 expected) internal pure returns (bool) {
        return expected != 0 && (uint8(cur >> 120) == expected || uint8(cur >> 248) == expected);
    }

    /// @notice Move the cursor with `expected` into the lower position.
    /// @dev If both cursors share the tag, the existing lower cursor is retained.
    /// @param cur Packed cursor or cursor pair.
    /// @param expected Identity tag to select.
    /// @return updated Cursor word with the selected lane in the lower position.
    function select(uint cur, uint8 expected) internal pure returns (uint updated) {
        if (uint8(cur >> 120) == expected) return cur;

        updated = (cur << 128) | (cur >> 128);
        if (uint8(updated >> 120) != expected) revert MissingCursor();
    }

    // Consumption

    /// @notice Return a cursor's absolute position and advance it.
    /// @dev Intended for fixed-width consumers that know their complete encoded size.
    /// @param cur Packed cursor or cursor pair.
    /// @param amount Number of bytes to consume.
    /// @return updated Cursor advanced by `amount`.
    /// @return abs Absolute pre-advance position.
    function consume(uint cur, uint amount) internal pure returns (uint updated, uint abs) {
        uint i = uint32(cur);
        uint len = uint32(cur >> 64);
        if (amount > len - i) revert OutOfBounds();
        abs = uint32(cur >> 32) + i;
        updated = cur + amount;
    }

    /// @notice Select a tagged cursor, return its absolute position, and advance it.
    /// @param cur Packed cursor or cursor pair.
    /// @param tag Identity tag to select.
    /// @param amount Number of bytes to consume.
    /// @return updated Cursor pair with the selected lane advanced.
    /// @return abs Absolute pre-advance position in the selected lane.
    function consume(uint cur, uint8 tag, uint amount) internal pure returns (uint updated, uint abs) {
        updated = select(cur, tag);

        uint i = uint32(updated);
        uint len = uint32(updated >> 64);
        if (amount > len - i) revert OutOfBounds();
        abs = uint32(updated >> 32) + i;
        updated += amount;
    }
}
