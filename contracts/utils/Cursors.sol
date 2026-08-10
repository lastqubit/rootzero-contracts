// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {clear32, max16, max32, max128} from "./Utils.sol";

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
/// bits  96-111   count (opaque consumer metadata)
/// bits 112-119   flags (consumer-defined)
/// bits 120-127   tag
///
/// A cursor is one 128-bit value with this layout. A pair is a 256-bit value
/// containing a lower cursor in bits 0-127 and an optional higher cursor in
/// bits 128-255. The lower cursor is the active cursor: navigation and
/// inspection operations target it, and `select` swaps a requested tagged
/// cursor into that position while preserving the pair.
///
/// A mark is a standalone cursor value used as an immutable positional
/// reference. It retains the cursor's offset, length, count, flags, and tag,
/// but may carry a different `i`. A mark has no intrinsic boundary or movement
/// semantics; callers may later use its position for comparison, validation,
/// seeking, or another operation. Because it has the ordinary single-cursor
/// layout, existing positional decoding and absolute-position rules also apply
/// to marks. A zero mark identifies the empty cursor at position zero; `before`
/// therefore treats it as already reached.
///
/// The zero word represents an absent cursor.
library Cursors {
    /// @dev A cursor position exceeds its logical length.
    error OutOfBounds();

    /// @dev A cursor is not positioned at the expected offset.
    error UnexpectedPosition();

    /// @dev Paired cursors must have different identity tags.
    error DuplicateTag(uint8 tag);

    /// @dev Neither packed cursor matches the requested identity.
    error MissingCursor();

    // Creation and sources

    /// @notice Create a cursor positioned at its beginning.
    /// @param offset Absolute source or buffer offset.
    /// @param len Logical byte length.
    /// @param items Opaque item count associated with the region.
    /// @param flags Consumer-defined flags.
    /// @param tag Cursor identity tag.
    /// @return cur Packed cursor.
    function create(uint offset, uint len, uint items, uint8 flags, uint8 tag) internal pure returns (uint cur) {
        cur |= max32(offset) << 32;
        cur |= max32(len) << 64;
        cur |= max16(items) << 96;
        cur |= uint(flags) << 112;
        cur |= uint(tag) << 120;
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
        abs = base(source);
        end = abs + source.length;
    }

    /// @notice Create a cursor backed by a calldata slice.
    /// @param source Calldata slice represented by the cursor.
    /// @param flags Consumer-defined flags.
    /// @param tag Cursor identity tag.
    /// @return cur Packed cursor positioned at the slice beginning.
    function wrap(bytes calldata source, uint8 flags, uint8 tag) internal pure returns (uint cur) {
        cur = create(base(source), source.length, 0, flags, tag);
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
    /// @return The lower cursor's offset, length, count, flags, and tag.
    function frame(uint cur) internal pure returns (uint) {
        return clear32(uint128(cur), 0);
    }

    /// @notice Return the absolute position of the lower cursor as `offset + i`.
    /// @dev Performs no bounds check.
    /// @param cur Packed cursor or cursor pair.
    /// @return Absolute current position.
    function absolute(uint cur) internal pure returns (uint) {
        return uint32(cur) + uint32(cur >> 32);
    }

    /// @notice Decode the consumer metadata and identity tag from the lower cursor.
    /// @param cur Packed cursor or cursor pair.
    /// @return items Opaque item count.
    /// @return flags Consumer-defined flags.
    /// @return tag Cursor identity tag.
    function meta(uint cur) internal pure returns (uint items, uint8 flags, uint8 tag) {
        items = uint16(cur >> 96);
        flags = uint8(cur >> 112);
        tag = uint8(cur >> 120);
    }

    /// @notice Return the opaque item count attached to the active cursor.
    function count(uint cur) internal pure returns (uint) {
        return uint16(cur >> 96);
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
        return more(cur) || more(cur >> 128);
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
        if (absolute(cur) != abs) revert UnexpectedPosition();
    }

    /// @notice Return whether the lower cursor contains `flag`.
    /// @param cur Packed cursor or cursor pair.
    /// @param flag Consumer-defined flag bit or bit set.
    /// @return Whether any requested flag bit is present.
    function flagged(uint cur, uint8 flag) internal pure returns (bool) {
        return uint8(cur >> 112) & flag != 0;
    }

    // Navigation

    /// @dev Return `cur` after ensuring its lower position does not exceed its length.
    /// @param cur Packed cursor or cursor pair.
    /// @return Validated cursor unchanged.
    function validate(uint cur) private pure returns (uint) {
        if (uint32(cur) > uint32(cur >> 64)) revert OutOfBounds();
        return cur;
    }

    /// @notice Move the lower cursor forward to `i`.
    /// @param cur Packed cursor or cursor pair.
    /// @param i New relative position; must not move backward.
    /// @return updated Cursor with the new lower position.
    function seek(uint cur, uint i) internal pure returns (uint updated) {
        uint current = uint32(cur);
        uint len = uint32(cur >> 64);
        if (i < current || i > len) revert OutOfBounds();
        updated = clear32(cur, 0) | i;
    }

    /// @notice Replace the lower cursor's position using an absolute position.
    /// @param cur Packed cursor or cursor pair.
    /// @param abs New absolute position.
    /// @return updated Cursor with the corresponding relative position.
    function seekAbs(uint cur, uint abs) internal pure returns (uint updated) {
        uint offset = uint32(cur >> 32);
        if (abs < offset) revert OutOfBounds();
        updated = seek(cur, abs - offset);
    }

    /// @notice Advance the current position of the lower cursor.
    /// @param cur Packed cursor or cursor pair.
    /// @param amount Number of bytes to advance.
    /// @return updated Cursor advanced by `amount`.
    function advance(uint cur, uint amount) internal pure returns (uint updated) {
        uint i = uint32(validate(cur));
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
        if (uint32(cur) > max32(len)) revert OutOfBounds();
        updated = clear32(cur, 64) | (len << 64);
    }

    /// @notice Create a child cursor over `[start, end)` within the lower cursor.
    /// @dev The child starts at position zero, has no recorded count, and uses the
    /// supplied tag. Any higher cursor is omitted.
    /// @param cur Parent cursor or cursor pair.
    /// @param start Child start relative to the parent base.
    /// @param end Child exclusive end relative to the parent base.
    /// @param tag Child identity tag.
    /// @return child Packed child cursor.
    function slice(uint cur, uint start, uint end, uint8 tag) internal pure returns (uint child) {
        (, uint offset, uint len) = decode(validate(cur));
        if (start > end || end > len) revert OutOfBounds();
        child = create(offset + start, end - start, 0, 0, tag);
    }

    // Pairing and selection

    /// @notice Combine two cursors into one packed word.
    /// @dev Zero represents absence and acts as the identity value.
    /// @param low Cursor placed in the lower lane.
    /// @param high Cursor placed in the higher lane.
    /// @return cur Packed cursor pair, or the nonzero cursor when one is absent.
    function pair(uint low, uint high) internal pure returns (uint cur) {
        low = validate(max128(low));
        high = validate(max128(high));

        if (low == 0) return high;
        if (high == 0) return low;

        uint8 tag = uint8(low >> 120);
        if (tag == uint8(high >> 120)) revert DuplicateTag(tag);

        cur = low | (high << 128);
    }

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

        updated = swap(cur);
        if (uint8(updated >> 120) != expected) revert MissingCursor();
    }

    // Marks

    /// @notice Select the live cursor whose frame matches the active cursor in `mark`.
    /// @dev Only the lower 128 bits of `mark` are considered. The returned value
    /// preserves the cursor pair and places the matching cursor in the lower half.
    /// A zero frame may select an empty cursor lane.
    /// @param cur Packed cursor or cursor pair to search.
    /// @param mark Cursor-shaped positional reference to match.
    /// @return located Cursor pair with the matching cursor active.
    function locate(uint cur, uint mark) internal pure returns (uint located) {
        uint expected = frame(mark);
        if (frame(cur) == expected) return cur;

        located = swap(cur);
        if (frame(located) != expected) revert MissingCursor();
    }

    /// @notice Return whether a matched cursor is positioned before `mark`.
    /// @dev Returns false at the mark and reverts after it. Only the active lower
    /// cursor in `mark` participates in the comparison. A zero mark represents
    /// the already-reached position of an empty cursor.
    /// @param cur Packed cursor or cursor pair containing the marked cursor.
    /// @param mark Cursor-shaped positional reference.
    /// @return Whether the live cursor position precedes the marked position.
    function before(uint cur, uint mark) internal pure returns (bool) {
        uint i = uint32(locate(cur, mark));
        uint target = uint32(mark);
        if (i > target) revert OutOfBounds();
        return i < target;
    }

    // Consumption

    /// @notice Return a cursor's absolute position and advance it.
    /// @dev Intended for fixed-width consumers that know their complete encoded size.
    /// @param cur Packed cursor or cursor pair.
    /// @param amount Number of bytes to consume.
    /// @return updated Cursor advanced by `amount`.
    /// @return abs Absolute pre-advance position.
    function consume(uint cur, uint amount) internal pure returns (uint updated, uint abs) {
        abs = Cursors.absolute(cur);
        updated = advance(cur, amount);
    }

    /// @notice Select a tagged cursor, return its absolute position, and advance it.
    /// @param cur Packed cursor or cursor pair.
    /// @param tag Identity tag to select.
    /// @param amount Number of bytes to consume.
    /// @return updated Cursor pair with the selected lane advanced.
    /// @return abs Absolute pre-advance position in the selected lane.
    function consume(uint cur, uint8 tag, uint amount) internal pure returns (uint updated, uint abs) {
        updated = select(cur, tag);
        (updated, abs) = consume(updated, amount);
    }
}
