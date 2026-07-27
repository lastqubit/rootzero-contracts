// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {max16, max32, max128} from "./Utils.sol";

/// @title Spans
/// @notice Shared packed state for reading or writing a grouped byte region.
/// @dev Cursor and buffer helpers may apply different behavior to a span, but
/// use the same representation and preserve the same fields.
/// @dev Each 128-bit span uses the following layout:
/// bits   0-31    i
/// bits  32-63    offset
/// bits  64-95    len
/// bits  96-111   groups
/// bits 112-119   flags (consumer-defined)
/// bits 120-127   tag
/// A packed word may contain a lower span in bits 0-127 and a higher span in
/// bits 128-255. Operations target the lower span; `select` swaps a requested
/// tagged span into that position.
library Spans {
    uint private constant FIELD_MASK = type(uint32).max;
    uint private constant OFFSET_SHIFT = 32;
    uint private constant LEN_SHIFT = 64;
    uint private constant GROUPS_SHIFT = 96;
    uint private constant FLAGS_SHIFT = 112;
    uint private constant TAG_SHIFT = 120;
    uint private constant SPAN_SHIFT = 128;
    uint private constant POSITIONS_MASK = FIELD_MASK | (FIELD_MASK << SPAN_SHIFT);

    /// @dev A span position exceeds its logical length.
    error OutOfBounds();

    /// @dev A span has not reached its logical end.
    error Incomplete();

    /// @dev A span is not positioned at the expected offset.
    error UnexpectedPosition();

    /// @dev Paired spans must have different identity tags.
    error DuplicateTag(uint8 tag);

    /// @dev Neither packed span has the requested tag.
    error MissingTag(uint8 tag);

    /// @notice Create a span positioned at its beginning.
    function create(
        uint offset,
        uint len,
        uint groups,
        uint8 flags,
        uint8 tag
    ) internal pure returns (uint cur) {
        max32(offset | len);
        max16(groups);

        cur = (offset << OFFSET_SHIFT) | (len << LEN_SHIFT) | (groups << GROUPS_SHIFT)
            | (uint(flags) << FLAGS_SHIFT) | (uint(tag) << TAG_SHIFT);
    }

    /// @notice Decode the positional fields from the lower span.
    function decode(uint cur) internal pure returns (uint i, uint offset, uint len) {
        i = uint32(cur);
        offset = uint32(cur >> OFFSET_SHIFT);
        len = uint32(cur >> LEN_SHIFT);
    }

    /// @notice Decode the consumer metadata and identity tag from the lower span.
    function meta(uint cur) internal pure returns (uint groups, uint8 flags, uint8 tag) {
        groups = uint16(cur >> GROUPS_SHIFT);
        flags = uint8(cur >> FLAGS_SHIFT);
        tag = uint8(cur >> TAG_SHIFT);
    }

    /// @notice Replace the current position of the lower span.
    function seek(uint cur, uint i) internal pure returns (uint updated) {
        uint len = uint32(cur >> LEN_SHIFT);
        if (i > len) revert OutOfBounds();
        updated = (cur & ~FIELD_MASK) | i;
    }

    /// @notice Advance the current position of the lower span.
    function advance(uint cur, uint amount) internal pure returns (uint updated) {
        uint i = uint32(cur);
        uint len = uint32(cur >> LEN_SHIFT);
        if (amount > len - i) revert OutOfBounds();
        updated = cur + amount;
    }

    /// @notice Replace the logical length of the lower span.
    /// @dev A span cannot be resized below its current position.
    function resize(uint cur, uint len) internal pure returns (uint updated) {
        max32(len);
        if (uint32(cur) > len) revert OutOfBounds();
        updated = (cur & ~(FIELD_MASK << LEN_SHIFT)) | (len << LEN_SHIFT);
    }

    /// @notice Create a child span over `[from, to)` within the lower span.
    /// @dev The child starts at position zero, has no groups, and uses the
    /// supplied tag. Any higher span is omitted.
    function slice(uint cur, uint from, uint to, uint8 tag) internal pure returns (uint child) {
        uint i = uint32(cur);
        uint offset = uint32(cur >> OFFSET_SHIFT);
        uint len = uint32(cur >> LEN_SHIFT);
        if (i > len) revert OutOfBounds();
        if (from > to || to > len) revert OutOfBounds();
        child = create(offset + from, to - from, 0, 0, tag);
    }

    /// @notice Return the distance from the current position to the span length.
    function remaining(uint cur) internal pure returns (uint) {
        uint i = uint32(cur);
        uint len = uint32(cur >> LEN_SHIFT);
        if (i > len) revert OutOfBounds();
        return len - i;
    }

    /// @notice Return whether both packed spans remain at their initial positions.
    function initial(uint cur) internal pure returns (bool) {
        return cur & POSITIONS_MASK == 0;
    }

    /// @notice Return whether the lower span's current position precedes its length.
    function more(uint cur) internal pure returns (bool) {
        return uint32(cur) < uint32(cur >> LEN_SHIFT);
    }

    /// @notice Return whether either packed span has remaining bytes.
    function any(uint cur) internal pure returns (bool) {
        return more(cur) || more(cur >> SPAN_SHIFT);
    }

    /// @notice Require both packed spans to be positioned at their logical ends.
    function complete(uint cur) internal pure {
        if (any(cur)) revert Incomplete();
    }

    /// @notice Require the lower span to be positioned at `i`.
    function expect(uint cur, uint i) internal pure {
        if (uint32(cur) != i) revert UnexpectedPosition();
    }

    /// @notice Combine two spans into one packed word.
    function pair(uint low, uint high) internal pure returns (uint cur) {
        max128(low | high);
        if (uint32(low) > uint32(low >> LEN_SHIFT) || uint32(high) > uint32(high >> LEN_SHIFT)) revert OutOfBounds();

        uint8 lowTag = uint8(low >> TAG_SHIFT);
        uint8 highTag = uint8(high >> TAG_SHIFT);
        if (lowTag == highTag) revert DuplicateTag(lowTag);

        cur = low | (high << SPAN_SHIFT);
    }

    /// @notice Swap the lower and higher spans.
    function swap(uint cur) internal pure returns (uint updated) {
        updated = (cur << SPAN_SHIFT) | (cur >> SPAN_SHIFT);
    }

    /// @notice Move the span with `expected` into the lower position.
    /// @dev If both spans share the tag, the existing lower span is retained.
    function select(uint cur, uint8 expected) internal pure returns (uint updated) {
        if (uint8(cur >> TAG_SHIFT) == expected) return cur;

        updated = swap(cur);
        if (uint8(updated >> TAG_SHIFT) != expected) revert MissingTag(expected);
    }
}
