// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AssetAmount, AccountAsset, AccountAmount, HostAmount, HostAccountAsset, Tx} from "../core/Types.sol";
import {Blocks} from "./Blocks.sol";
import {Sizes, Specs} from "./Specs.sol";
import {Keys} from "./Keys.sol";
import {Spans} from "../utils/Spans.sol";

/// @notice Logical cursor lanes used by execution-owned cursor pairs.
/// @notice Zero-copy view into a calldata block stream.
/// All positions (`i`) are byte offsets relative to the start of the source region.
/// The absolute calldata location of byte `i` is `offset + i`.
struct Cur {
    /// @dev Lower 128-bit cursor lane:
    /// bits   0–31    i
    /// bits  32–63    offset
    /// bits  64–95    len
    /// bits  96–111   groups (reserved for the scoped run group count)
    /// bits 112–119   flags (consumer-defined)
    /// bits 120–127   tag (optional cursor identity)
    /// A second tagged cursor may occupy bits 128–255. Cursor operations always
    /// use the lower lane; `Spans.select` swaps the requested lane into place.
    uint packed;
}

using Cursors for Cur;

/// @title Cursors
/// @notice Calldata block stream parser for the rootzero protocol.
/// A `Cur` is a lightweight view into a slice of `msg.data`; no data is copied.
/// Blocks are encoded as `[bytes4 key][bytes4 payloadLen][payload]`.
/// Consuming packed helpers take `cur` and return the `updated` cursor first.
library Cursors {
    /// @dev `complete` called but the cursor has not consumed exactly to `len`.
    error IncompleteCursor();
    /// @dev `scope` found zero blocks of the expected key; the cursor region is empty.
    error ZeroCursor();
    /// @dev `scope` was called with a zero group size.
    error ZeroGroup();
    /// @dev An account field was required but the block or fallback was zero.
    error ZeroAccount();
    /// @dev A node field was required but the block or fallback was zero.
    error ZeroNode();
    /// @dev A field value did not match the expected value.
    error UnexpectedValue();
    /// @dev Prime block counts are not divisible by, or do not match, their declared group sizes.
    error BadRatio();

    // -------------------------------------------------------------------------
    // Internal cursor support
    // -------------------------------------------------------------------------

    /// @dev Reconcile two optional group counts.
    function reconcile(uint a, uint b) internal pure returns (uint groups) {
        if (a != 0 && b != 0 && a != b) revert BadRatio();
        groups = a != 0 ? a : b;
    }

    /// @dev Validate a raw block and optionally require its following position.
    function expect(
        uint offset,
        uint limit,
        uint i,
        uint end,
        bytes4 key,
        uint min,
        uint max
    ) private pure returns (uint abs, uint next) {
        (abs, next) = Blocks.expect(offset, limit, i, key, min, max);
        if (end != 0 && next != end) revert IncompleteCursor();
    }

    // -------------------------------------------------------------------------
    // Cursor construction and navigation
    // -------------------------------------------------------------------------

    /// @notice Create a cursor backed by a calldata slice.
    // @param source Calldata slice that forms the block stream.
    // @return cur Cursor positioned at the beginning of `source`.
    function open(bytes calldata source) internal pure returns (uint cur) {
        uint offset;
        // Extract the absolute calldata offset of `source` using inline assembly,
        // as Solidity does not expose this directly for calldata slices.
        assembly ("memory-safe") {
            offset := source.offset
        }
        cur = Spans.create(offset, source.length, 0, 0, 0);
    }

    /// @notice Create a cursor backed by `source[i:]`.
    // @param source Calldata slice that forms the parent block stream.
    // @param i Start byte offset within `source`.
    // @return cur Cursor positioned at the beginning of `source[i:]`.
    function open(bytes calldata source, uint i) internal pure returns (uint cur) {
        return open(source[i:]);
    }

    /// @notice Create a cursor over `source` and restrict it to its first grouped run.
    /// Equivalent to `open(source)`, reading the current key, then `scope(key, group)`.
    /// When `group` is zero, `source` must be empty and the function returns an empty cursor.
    // @param source Calldata slice that forms the block stream.
    // @param group Expected block group size (e.g. 1 for single, 2 for paired); 0 means empty.
    // @param expected Required group count, or zero to accept the count found in `source`.
    // @param tag Immutable identity assigned when the cursor is created.
    // @return cur Cursor with `len` truncated to the end of the first run in `source`.
    // @return groups Reconciled group count (`block count / group`), or `expected` for an empty lane.
    function initMeta(
        bytes calldata source,
        uint group,
        uint expected,
        uint8 tag
    ) internal pure returns (uint cur, uint groups) {
        uint offset;
        assembly ("memory-safe") {
            offset := source.offset
        }
        cur = Spans.create(offset, source.length, 0, 0, tag);
        (, , uint len) = Spans.decode(cur);
        if (group == 0) {
            if (len != 0) revert IncompleteCursor();
            return (cur, expected);
        }
        if (len == 0) revert ZeroCursor();
        (bytes4 key, ) = Blocks.header(offset, len, 0);
        (cur, groups) = scope(cur, key, group);
        groups = reconcile(groups, expected);
    }

    /// @notice Advance the cursor to a later absolute position within the source region.
    /// Reverts with `IncompleteCursor` if `i` is before `cur.i`.
    /// `Spans.seek` validates that `i` does not exceed the cursor region length.
    // @param cur Cursor to advance.
    // @param i New read position (byte offset relative to source start).
    function skipTo(uint cur, uint i) internal pure returns (uint updated) {
        (uint current, , ) = Spans.decode(cur);
        if (current > i) revert IncompleteCursor();
        updated = Spans.seek(cur, i);
    }

    /// @notice Return the full cursor region as a calldata slice.
    /// Does not advance the cursor; `cur.i` is ignored.
    // @param cur Cursor whose backing region should be returned.
    // @return data Calldata view over `[cur.offset, cur.offset + cur.len)`.
    function raw(uint cur) internal pure returns (bytes calldata data) {
        (, uint offset, uint len) = Spans.decode(cur);
        if (len > msg.data.length || offset > msg.data.length - len) revert Blocks.MalformedBlocks();
        data = msg.data[offset:offset + len];
    }

    /// @notice Return a sub-range of the cursor region as a calldata slice.
    /// Does not advance the cursor; `cur.i` is ignored.
    // @param cur Source cursor.
    // @param from Start byte offset within the source region (inclusive).
    // @param to End byte offset within the source region (exclusive).
    // @return data Calldata view over the requested sub-range.
    function raw(uint cur, uint from, uint to) internal pure returns (bytes calldata data) {
        (, uint offset, uint len) = Spans.decode(cur);
        if (from > to || to > len) revert Blocks.MalformedBlocks();
        if (len > msg.data.length || offset > msg.data.length - len) revert Blocks.MalformedBlocks();
        data = msg.data[offset + from:offset + to];
    }

    /// @notice Hash a sub-range of the cursor region.
    /// Does not advance the cursor; `from` and `to` are relative to the source region.
    // @param cur Source cursor.
    // @param from Start byte offset within the source region (inclusive).
    // @param to End byte offset within the source region (exclusive).
    // @return digest Keccak256 hash of the requested sub-range.
    function hash(uint cur, uint from, uint to) internal pure returns (bytes32 digest) {
        digest = keccak256(raw(cur, from, to));
    }

    /// @notice Read a block header at position `i` without advancing the cursor.
    // @param cur Source cursor.
    // @param i Byte offset of the block header within the source region.
    // @return key Four-byte block type identifier.
    // @return len Payload byte length declared in the header.
    function peek(uint cur, uint i) internal pure returns (bytes4 key, uint len) {
        (, uint offset, uint end) = Spans.decode(cur);
        return Blocks.header(offset, end, i);
    }

    /// @notice Return the byte offset immediately past the block at the current cursor position.
    /// Does not advance the cursor.
    // @param cur Source cursor.
    // @return Byte offset immediately past the current block, relative to the source region.
    function past(uint cur) internal pure returns (uint) {
        (uint i, uint offset, uint end) = Spans.decode(cur);
        (, uint len) = Blocks.header(offset, end, i);
        return i + Sizes.Header + len;
    }

    /// @notice Return true if position `i` is at a block header with the given key.
    /// Returns false when `i` is out of bounds or the key differs.
    // @param cur Source cursor.
    // @param i Byte offset of the block header within the source region.
    // @param key Expected block type identifier.
    // @return Whether the block header at `i` uses `key`.
    function hasAt(uint cur, uint i, bytes4 key) internal pure returns (bool) {
        (, uint offset, uint len) = Spans.decode(cur);
        return Blocks.hasAt(offset, len, i, key);
    }

    /// @notice Return true if the current cursor position is at a block header with the given key.
    /// Returns false when `cur.i` is out of bounds or the key differs.
    // @param cur Source cursor.
    // @param key Expected block type identifier.
    // @return Whether the block header at `cur.i` uses `key`.
    function isAt(uint cur, bytes4 key) internal pure returns (bool) {
        (uint i, uint offset, uint len) = Spans.decode(cur);
        return Blocks.hasAt(offset, len, i, key);
    }

    /// @notice Enter a block at the current position and return its next offset.
    /// Advances `cur.i` past the block header so the payload can be parsed
    /// directly from the same cursor. The returned `next` is the byte offset
    /// immediately after the block payload, relative to the current cursor region.
    // @param cur Cursor positioned at the expected block; advanced past the 8-byte header.
    // @param key Expected block key.
    // @param min Minimum acceptable payload length.
    // @param max Maximum acceptable payload length; 0 means unbounded.
    // @return next Byte offset immediately after the block payload.
    function enter(
        uint cur,
        bytes4 key,
        uint min,
        uint max
    ) private pure returns (uint updated, uint next) {
        (uint i, uint offset, uint end) = Spans.decode(cur);
        (, next) = Blocks.expect(offset, end, i, key, min, max);
        updated = cur + Sizes.Header;
    }

    /// @notice Enter the block described by `spec` at the current position.
    function enter(uint cur, uint spec) internal pure returns (uint updated, uint next) {
        return enter(cur, Specs.key(spec), Specs.min(spec), Specs.max(spec));
    }

    /// @notice Validate the block described by `spec` at position `i`.
    function expect(uint cur, uint i, uint end, uint spec) internal pure returns (uint abs, uint next) {
        (, uint offset, uint len) = Spans.decode(cur);
        return expect(offset, len, i, end, Specs.key(spec), Specs.min(spec), Specs.max(spec));
    }

    /// @notice Validate and consume the current block, advancing `cur.i` past it.
    // @param cur Cursor to advance.
    // @param end Required next offset after the block; 0 means no exact-end check.
    // @param key Expected block key.
    // @param min Minimum payload length.
    // @param max Maximum payload length (0 = unbounded).
    // @return abs Absolute calldata offset of the payload start.
    function consume(
        uint cur,
        uint end,
        bytes4 key,
        uint min,
        uint max
    ) private pure returns (uint updated, uint abs) {
        (uint i, uint offset, uint len) = Spans.decode(cur);
        uint next;
        (abs, next) = expect(offset, len, i, end, key, min, max);
        updated = Spans.seek(cur, next);
    }

    /// @notice Consume the current block described by `spec`.
    function consume(uint cur, uint end, uint spec) internal pure returns (uint updated, uint abs) {
        return consume(cur, end, Specs.key(spec), Specs.min(spec), Specs.max(spec));
    }

    /// @notice Count consecutive blocks of the same key starting at `i`.
    // @param cur Source cursor.
    // @param i Starting byte offset within the source region.
    // @param key Block type to count.
    // @return total Number of consecutive matching blocks.
    // @return next Byte offset immediately after the last counted block.
    function run(uint cur, uint i, bytes4 key) internal pure returns (uint total, uint next) {
        (, uint offset, uint end) = Spans.decode(cur);
        return Blocks.run(offset, end, i, key);
    }

    /// @notice Restrict the cursor to the consecutive run of `key` at its current position.
    /// Counts the run, truncates `cur.len` to the run end, and validates that the
    /// count is a multiple of `group`.
    // @param cur Cursor to restrict; `cur.len` is updated in place.
    // @param key Expected block type identifier of the run.
    // @param group Expected group size (e.g. 1 for single-asset, 2 for paired input/output).
    // @return groups Number of groups represented by the run (`block count / group`).
    function scope(uint cur, bytes4 key, uint group) internal pure returns (uint updated, uint groups) {
        if (group == 0) revert ZeroGroup();
        (uint i, uint offset, uint end) = Spans.decode(cur);
        (uint count, uint next) = Blocks.run(offset, end, i, key);
        if (count == 0) revert ZeroCursor();
        if (count % group != 0) revert BadRatio();
        updated = Spans.resize(cur, next);
        groups = count / group;
    }

    /// @notice Scan forward from `i` for the first block matching `key`.
    // @param cur Source cursor.
    // @param i Starting byte offset for the search.
    // @param key Block type to find.
    // @return Byte offset of the matching block, or `cur.len` if not found.
    function find(uint cur, uint i, bytes4 key) internal pure returns (uint) {
        (, uint offset, uint end) = Spans.decode(cur);
        return Blocks.find(offset, end, i, key);
    }

    /// @notice Scan forward from the current position for the first block matching `key`.
    // @param cur Source cursor.
    // @param key Block type to find.
    // @return Byte offset of the matching block, or `cur.len` if not found.
    function find(uint cur, bytes4 key) internal pure returns (uint) {
        (uint i, uint offset, uint end) = Spans.decode(cur);
        return Blocks.find(offset, end, i, key);
    }

    /// @notice Consume a LIST block and return a cursor over its payload.
    /// Advances `cur.i` past the full list while the returned cursor is scoped to
    /// the list members as a fresh zero-based region.
    // @param cur Cursor positioned at a list block; advanced past the full list.
    // @return items Cursor scoped to the list payload.
    function list(uint cur) internal pure returns (uint updated, uint items) {
        (uint i, uint offset, uint len) = Spans.decode(cur);
        (uint abs, uint next) = expect(offset, len, i, 0, Keys.List, 0, 0);
        items = Spans.create(abs, next - i - Sizes.Header, 0, 0, 0);
        updated = Spans.seek(cur, next);
    }

    /// @notice Consume a block with the given key at the current position and return a cursor over the full block slice.
    /// Advances `cur.i` past the block while the returned cursor is scoped to the
    /// full block bytes as a fresh zero-based region.
    // @param cur Cursor positioned at the expected block.
    // @param key Expected block type key.
    // @return out Cursor scoped to the full block.
    function take(uint cur, bytes4 key) internal pure returns (uint updated, uint child) {
        (uint i, uint offset, uint len) = Spans.decode(cur);
        (, uint next) = expect(offset, len, i, 0, key, 0, 0);
        child = Spans.create(offset + i, next - i, 0, 0, 0);
        updated = Spans.seek(cur, next);
    }

    /// @notice Return whether the remaining cursor region is empty or exactly one block with `key`.
    /// Returns false for an empty remaining region. Reverts if the next block has another key or
    /// if a matching block is followed by trailing bytes.
    // @param cur Source cursor.
    // @param key Expected optional block key.
    // @return Whether the remaining region contains exactly one block with `key`.
    function maybeOnly(uint cur, bytes4 key) internal pure returns (bool) {
        (uint i, uint offset, uint len) = Spans.decode(cur);
        if (i == len) return false;
        if (!Blocks.hasAt(offset, len, i, key)) revert Blocks.InvalidBlock();
        (, uint size) = Blocks.header(offset, len, i);
        if (i + Sizes.Header + size != len) revert IncompleteCursor();
        return true;
    }

    /// @notice Consume an optional block with the given key and return a cursor over the full block slice.
    /// If the current block key does not match, returns an empty cursor and leaves `cur.i` unchanged.
    /// Otherwise behaves like `take(cur, key)`.
    // @param cur Cursor positioned at an optional block.
    // @param key Optional block type key.
    // @return out Cursor scoped to the full matching block, or empty when no matching block is present.
    function maybeTake(uint cur, bytes4 key) internal pure returns (uint updated, uint child) {
        (uint i, uint offset, uint len) = Spans.decode(cur);
        if (!Blocks.hasAt(offset, len, i, key)) {
            return (cur, Spans.create(offset + i, 0, 0, 0, 0));
        }

        (, uint next) = expect(offset, len, i, 0, key, 0, 0);
        child = Spans.create(offset + i, next - i, 0, 0, 0);
        updated = Spans.seek(cur, next);
    }

    /// @notice Assert that the cursor has consumed its entire source region.
    /// Reverts with `IncompleteCursor` when `cur.i != cur.len`.
    // @param cur Cursor to check.
    function complete(uint cur) internal pure {
        if (Spans.more(cur)) revert IncompleteCursor();
    }

    // -------------------------------------------------------------------------
    // Raw calldata loaders
    // -------------------------------------------------------------------------

    /// @notice Read the next calldata word from the cursor and advance by `n` bytes.
    /// @dev Performs no bounds, key, length, or cursor checks. Always loads 32 bytes;
    ///      callers may cast the returned word to `bytesN` when `n < 32`.
    // @param cur Cursor whose current position is advanced by `n` bytes.
    // @param n Number of bytes to advance.
    // @return value Loaded word.
    function read(uint cur, uint n) internal pure returns (uint updated, bytes32 value) {
        uint abs = Spans.abs(cur);
        assembly ("memory-safe") {
            value := calldataload(abs)
        }
        updated = cur + n;
    }

    /// @notice Read the next byte from the cursor and advance by 1 byte.
    /// @dev Performs no bounds, key, length, or cursor checks.
    // @param cur Cursor whose current position is advanced by 1 byte.
    // @return value Loaded bytes1 value.
    function read1(uint cur) internal pure returns (uint updated, bytes1 value) {
        bytes32 word;
        (updated, word) = read(cur, 1);
        value = bytes1(word);
    }

    /// @notice Read the next 2 bytes from the cursor and advance by 2 bytes.
    /// @dev Performs no bounds, key, length, or cursor checks.
    // @param cur Cursor whose current position is advanced by 2 bytes.
    // @return value Loaded bytes2 value.
    function read2(uint cur) internal pure returns (uint updated, bytes2 value) {
        bytes32 word;
        (updated, word) = read(cur, 2);
        value = bytes2(word);
    }

    /// @notice Read the next 4 bytes from the cursor and advance by 4 bytes.
    /// @dev Performs no bounds, key, length, or cursor checks.
    // @param cur Cursor whose current position is advanced by 4 bytes.
    // @return value Loaded bytes4 value.
    function read4(uint cur) internal pure returns (uint updated, bytes4 value) {
        bytes32 word;
        (updated, word) = read(cur, 4);
        value = bytes4(word);
    }

    /// @notice Read the next 8 bytes from the cursor and advance by 8 bytes.
    /// @dev Performs no bounds, key, length, or cursor checks.
    // @param cur Cursor whose current position is advanced by 8 bytes.
    // @return value Loaded bytes8 value.
    function read8(uint cur) internal pure returns (uint updated, bytes8 value) {
        bytes32 word;
        (updated, word) = read(cur, 8);
        value = bytes8(word);
    }

    /// @notice Read the next 16 bytes from the cursor and advance by 16 bytes.
    /// @dev Performs no bounds, key, length, or cursor checks.
    // @param cur Cursor whose current position is advanced by 16 bytes.
    // @return value Loaded bytes16 value.
    function read16(uint cur) internal pure returns (uint updated, bytes16 value) {
        bytes32 word;
        (updated, word) = read(cur, 16);
        value = bytes16(word);
    }

    /// @notice Read the next 32-byte word from the cursor and advance by one word.
    /// @dev Performs no bounds, key, length, or cursor checks.
    // @param cur Cursor whose current position is advanced by 32 bytes.
    // @return value Loaded word.
    function read32(uint cur) internal pure returns (uint updated, bytes32 value) {
        return read(cur, 32);
    }

    /// @notice Read the next uint from the cursor and advance by one word.
    /// @dev Performs no bounds, key, length, or cursor checks.
    // @param cur Cursor whose current position is advanced by 32 bytes.
    // @return value Loaded uint value.
    function readUint(uint cur) internal pure returns (uint updated, uint value) {
        bytes32 word;
        (updated, word) = read(cur, 32);
        value = uint(word);
    }

    /// @notice Read the next two 32-byte words from the cursor and advance by 64 bytes.
    /// @dev Performs no bounds, key, length, or cursor checks.
    // @param cur Cursor whose current position is advanced by 64 bytes.
    // @return a First loaded word.
    // @return b Second loaded word.
    function read64(uint cur) internal pure returns (uint updated, bytes32 a, bytes32 b) {
        uint abs = Spans.abs(cur);
        assembly ("memory-safe") {
            a := calldataload(abs)
            b := calldataload(add(abs, 0x20))
        }
        updated = cur + 64;
    }

    /// @notice Read the next three 32-byte words from the cursor and advance by 96 bytes.
    /// @dev Performs no bounds, key, length, or cursor checks.
    // @param cur Cursor whose current position is advanced by 96 bytes.
    // @return a First loaded word.
    // @return b Second loaded word.
    // @return c Third loaded word.
    function read96(uint cur) internal pure returns (uint updated, bytes32 a, bytes32 b, bytes32 c) {
        uint abs = Spans.abs(cur);
        assembly ("memory-safe") {
            a := calldataload(abs)
            b := calldataload(add(abs, 0x20))
            c := calldataload(add(abs, 0x40))
        }
        updated = cur + 96;
    }

    /// @notice Consume the next 32-byte word and require it to match `expected`.
    /// @dev Performs no bounds, key, length, or cursor checks beyond the value comparison.
    // @param cur Cursor whose current position is advanced by 32 bytes.
    // @param expected Required word value.
    function require32(uint cur, bytes32 expected) internal pure returns (uint updated) {
        bytes32 value;
        (updated, value) = read32(cur);
        if (value != expected) revert UnexpectedValue();
    }

    // -------------------------------------------------------------------------
    // unpack* - consume current block and decode payload fields
    // -------------------------------------------------------------------------

    // Generic fixed-width decoders

    /// @notice Consume a dynamic block with the given key and return the raw payload as a calldata slice.
    /// The payload length is variable; the returned slice covers the entire payload.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected dynamic block specification.
    // @return data Raw block payload bytes.
    function unpackRaw(uint cur, uint spec) internal pure returns (uint updated, bytes calldata data) {
        (uint i, uint offset, uint len) = Spans.decode(cur);
        (uint abs, uint next) =
            expect(offset, len, i, 0, Specs.key(spec), Specs.min(spec), Specs.max(spec));
        data = msg.data[abs:offset + next];
        updated = Spans.seek(cur, next);
    }

    /// @notice Consume a reserved BYTES block and return its raw payload.
    // @param cur Cursor; advanced past the BYTES block.
    // @return data Raw BYTES payload.
    function unpackBytes(uint cur) internal pure returns (uint updated, bytes calldata data) {
        uint next;
        (data, next) = Blocks.unpackBytes(Spans.abs(cur));
        updated = Spans.seekAbs(cur, next);
    }

    /// @notice Consume a reserved STRING block and return its UTF-8 payload.
    // @param cur Cursor; advanced past the STRING block.
    // @return data Decoded STRING payload.
    function unpackString(uint cur) internal pure returns (uint updated, string memory data) {
        bytes calldata value;
        uint next;
        (value, next) = Blocks.unpackString(Spans.abs(cur));
        updated = Spans.seekAbs(cur, next);
        data = string(value);
    }

    /// @notice Consume a LABEL block and return its fields.
    // @param cur Cursor; advanced past the LABEL block.
    // @return id Node ID being labelled.
    // @return namespace Label namespace.
    // @return name Label value.
    function unpackLabel(
        uint cur
    ) internal pure returns (uint updated, uint id, bytes32 namespace, string memory name) {
        uint next;
        (id, namespace, name, next) = Blocks.unpackLabel(Spans.abs(cur));
        updated = Spans.seekAbs(cur, next);
    }

    /// @notice Consume a SCHEMA block and return its fields.
    // @param cur Cursor; advanced past the SCHEMA block.
    // @return spec Block specification being defined.
    // @return body Schema DSL string describing the block payload body.
    // @return name Optional block alias.
    function unpackSchema(
        uint cur
    ) internal pure returns (uint updated, uint spec, string memory body, bytes32 name) {
        uint next;
        (spec, body, name, next) = Blocks.unpackSchema(Spans.abs(cur));
        updated = Spans.seekAbs(cur, next);
    }

    /// @notice Consume a dynamic block with a single bytes32 payload.
    // @param cur Cursor; advanced past the block.
    // @param spec Block specification supplying the expected key.
    // @return value Decoded bytes32.
    function unpack32(uint cur, uint spec) internal pure returns (uint updated, bytes32 value) {
        uint abs;
        (updated, abs) = consume(cur, 0, Specs.key(spec), 32, 32);
        value = bytes32(msg.data[abs:abs + 32]);
    }

    /// @notice Consume a dynamic block with two bytes32 payload words.
    // @param cur Cursor; advanced past the block.
    // @param spec Block specification supplying the expected key.
    // @return a First decoded bytes32.
    // @return b Second decoded bytes32.
    function unpack64(uint cur, uint spec) internal pure returns (uint updated, bytes32 a, bytes32 b) {
        uint abs;
        (updated, abs) = consume(cur, 0, Specs.key(spec), 64, 64);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
    }

    /// @notice Consume a dynamic block with three bytes32 payload words.
    // @param cur Cursor; advanced past the block.
    // @param spec Block specification supplying the expected key.
    // @return a First decoded bytes32.
    // @return b Second decoded bytes32.
    // @return c Third decoded bytes32.
    function unpack96(
        uint cur,
        uint spec
    ) internal pure returns (uint updated, bytes32 a, bytes32 b, bytes32 c) {
        uint abs;
        (updated, abs) = consume(cur, 0, Specs.key(spec), 96, 96);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
    }

    /// @notice Consume a dynamic block with a 128-byte payload (four 32-byte words).
    // @param cur Cursor; advanced past the block.
    // @param spec Block specification supplying the expected key.
    // @return a First decoded bytes32.
    // @return b Second decoded bytes32.
    // @return c Third decoded bytes32.
    // @return d Fourth decoded bytes32.
    function unpack128(
        uint cur,
        uint spec
    ) internal pure returns (uint updated, bytes32 a, bytes32 b, bytes32 c, bytes32 d) {
        uint abs;
        (updated, abs) = consume(cur, 0, Specs.key(spec), 128, 128);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
        d = bytes32(msg.data[abs + 96:abs + 128]);
    }

    /// @notice Consume a dynamic block with a 160-byte payload (five 32-byte words).
    // @param cur Cursor; advanced past the block.
    // @param spec Block specification supplying the expected key.
    // @return a First decoded bytes32.
    // @return b Second decoded bytes32.
    // @return c Third decoded bytes32.
    // @return d Fourth decoded bytes32.
    // @return e Fifth decoded bytes32.
    function unpack160(
        uint cur,
        uint spec
    ) internal pure returns (uint updated, bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e) {
        uint abs;
        (updated, abs) = consume(cur, 0, Specs.key(spec), 160, 160);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
        d = bytes32(msg.data[abs + 96:abs + 128]);
        e = bytes32(msg.data[abs + 128:abs + 160]);
    }

    // Generic typed-shape decoders

    /// @notice Consume a fixed-size asset amount block and return asset and amount.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected block specification.
    // @return asset Asset identifier.
    // @return amount Scalar amount value.
    function unpackAssetAmount(
        uint cur,
        uint spec
    ) internal pure returns (uint updated, bytes32 asset, uint amount) {
        bytes32 a;
        bytes32 b;
        (updated, a, b) = unpack64(cur, spec);
        asset = a;
        amount = uint(b);
    }

    /// @notice Consume a fixed-size account amount block and return account, asset, and amount.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected block specification.
    // @return account Account identifier.
    // @return asset Asset identifier.
    // @return amount Scalar amount value.
    function unpackAccountAmount(
        uint cur,
        uint spec
    ) internal pure returns (uint updated, bytes32 account, bytes32 asset, uint amount) {
        bytes32 a;
        bytes32 b;
        bytes32 c;
        (updated, a, b, c) = unpack96(cur, spec);
        account = a;
        asset = b;
        amount = uint(c);
    }

    /// @notice Consume a fixed-size host amount block and return host, asset, and amount.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected block specification.
    // @return host Host node ID.
    // @return asset Asset identifier.
    // @return amount Scalar amount value.
    function unpackHostAmount(
        uint cur,
        uint spec
    ) internal pure returns (uint updated, uint host, bytes32 asset, uint amount) {
        bytes32 a;
        bytes32 b;
        bytes32 c;
        (updated, a, b, c) = unpack96(cur, spec);
        host = uint(a);
        asset = b;
        amount = uint(c);
    }

    /// @notice Consume a fixed-size host account asset block and return host, account, and asset.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected block specification.
    // @return host Host node ID.
    // @return account Account identifier.
    // @return asset Asset identifier.
    function unpackHostAccountAsset(
        uint cur,
        uint spec
    ) internal pure returns (uint updated, uint host, bytes32 account, bytes32 asset) {
        bytes32 a;
        bytes32 b;
        bytes32 c;
        (updated, a, b, c) = unpack96(cur, spec);
        host = uint(a);
        account = b;
        asset = c;
    }

    /// @notice Consume a fixed-size transaction block and return from, to, asset, and amount.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected block specification.
    // @return from Source account identifier.
    // @return to Destination account identifier.
    // @return asset Asset identifier.
    // @return amount Scalar amount value.
    function unpackTransaction(
        uint cur,
        uint spec
    ) internal pure returns (uint updated, bytes32 from, bytes32 to, bytes32 asset, uint amount) {
        bytes32 a;
        bytes32 b;
        bytes32 c;
        bytes32 d;
        (updated, a, b, c, d) = unpack128(cur, spec);
        from = a;
        to = b;
        asset = c;
        amount = uint(d);
    }

    // Type-specific fixed-width decoders

    /// @notice Consume an ACCOUNT block and return the account.
    // @param cur Cursor; advanced past the block.
    // @return account Account identifier.
    function unpackAccount(uint cur) internal pure returns (uint updated, bytes32 account) {
        uint abs = Spans.abs(cur);
        account = Blocks.unpackAccount(abs);
        updated = Spans.advance(cur, Sizes.B32);
    }

    /// @notice Consume a NODE block and return the node ID.
    // @param cur Cursor; advanced past the block.
    // @return node Node identifier.
    function unpackNode(uint cur) internal pure returns (uint updated, uint node) {
        uint abs = Spans.abs(cur);
        node = Blocks.unpackNode(abs);
        updated = Spans.advance(cur, Sizes.B32);
    }

    /// @notice Consume a FEE block and return the amount.
    // @param cur Cursor; advanced past the block.
    // @return amount Fee amount.
    function unpackFee(uint cur) internal pure returns (uint updated, uint amount) {
        uint abs = Spans.abs(cur);
        amount = Blocks.unpackFee(abs);
        updated = Spans.advance(cur, Sizes.Fee);
    }

    /// @notice Consume an ASSET block and return the asset identifier.
    // @param cur Cursor; advanced past the block.
    // @return asset Asset identifier.
    function unpackAsset(uint cur) internal pure returns (uint updated, bytes32 asset) {
        uint abs = Spans.abs(cur);
        asset = Blocks.unpackAsset(abs);
        updated = Spans.advance(cur, Sizes.B32);
    }

    /// @notice Consume an ACCOUNT_ASSET form block and return its fields as separate values.
    // @param cur Cursor; advanced past the block.
    // @return account Account identifier.
    // @return asset Asset identifier.
    function unpackAccountAsset(
        uint cur
    ) internal pure returns (uint updated, bytes32 account, bytes32 asset) {
        uint abs = Spans.abs(cur);
        (account, asset) = Blocks.unpackAccountAsset(abs);
        updated = Spans.advance(cur, Sizes.B64);
    }

    /// @notice Consume an ACCOUNT_ASSET form block and return its fields as a struct.
    // @param cur Cursor; advanced past the block.
    // @return value Decoded account and asset.
    function unpackAccountAssetValue(
        uint cur
    ) internal pure returns (uint updated, AccountAsset memory value) {
        (updated, value.account, value.asset) = unpackAccountAsset(cur);
    }

    /// @notice Consume a BOUNTY block and return the reward amount and relayer.
    // @param cur Cursor; advanced past the block.
    // @return amount Relayer reward amount.
    // @return relayer Relayer account identifier.
    function unpackBounty(uint cur) internal pure returns (uint updated, uint amount, bytes32 relayer) {
        uint abs = Spans.abs(cur);
        (amount, relayer) = Blocks.unpackBounty(abs);
        updated = Spans.advance(cur, Sizes.Bounty);
    }

    /// @notice Consume an AMOUNT block and return its fields as separate values.
    // @param cur Cursor; advanced past the block.
    // @return asset Asset identifier.
    // @return amount Token amount.
    function unpackAmount(uint cur) internal pure returns (uint updated, bytes32 asset, uint amount) {
        uint abs = Spans.abs(cur);
        (asset, amount) = Blocks.unpackAmount(abs);
        updated = Spans.advance(cur, Sizes.Amount);
    }

    /// @notice Consume an AMOUNT block and return its fields as a struct.
    // @param cur Cursor; advanced past the block.
    // @return value Decoded asset and amount.
    function unpackAmountValue(uint cur) internal pure returns (uint updated, AssetAmount memory value) {
        (updated, value.asset, value.amount) = unpackAmount(cur);
    }

    /// @notice Consume a BALANCE block and return its fields as separate values.
    // @param cur Cursor; advanced past the block.
    // @return asset Asset identifier.
    // @return amount Token amount.
    function unpackBalance(uint cur) internal pure returns (uint updated, bytes32 asset, uint amount) {
        uint abs = Spans.abs(cur);
        (asset, amount) = Blocks.unpackBalance(abs);
        updated = Spans.advance(cur, Sizes.Balance);
    }

    /// @notice Consume a BALANCE block and return its fields as a struct.
    // @param cur Cursor; advanced past the block.
    // @return value Decoded asset and amount.
    function unpackBalanceValue(uint cur) internal pure returns (uint updated, AssetAmount memory value) {
        (updated, value.asset, value.amount) = unpackBalance(cur);
    }

    /// @notice Consume a HOST_ACCOUNT_ASSET form block and return its fields as separate values.
    // @param cur Cursor; advanced past the block.
    // @return host Host node ID.
    // @return account Account identifier.
    // @return asset Asset identifier.
    function unpackHostAccountAsset(
        uint cur
    ) internal pure returns (uint updated, uint host, bytes32 account, bytes32 asset) {
        uint abs = Spans.abs(cur);
        (host, account, asset) = Blocks.unpackHostAccountAsset(abs);
        updated = Spans.advance(cur, Sizes.B96);
    }

    /// @notice Consume a HOST_ACCOUNT_ASSET form block and return its fields as a struct.
    // @param cur Cursor; advanced past the block.
    // @return value Decoded host, account, and asset.
    function unpackHostAccountAssetValue(
        uint cur
    ) internal pure returns (uint updated, HostAccountAsset memory value) {
        (updated, value.host, value.account, value.asset) = unpackHostAccountAsset(cur);
    }

    /// @notice Consume an ACCOUNT_AMOUNT form block and return its fields as separate values.
    // @param cur Cursor; advanced past the block.
    // @return account Account identifier.
    // @return asset Asset identifier.
    // @return amount Token amount.
    function unpackAccountAmount(
        uint cur
    ) internal pure returns (uint updated, bytes32 account, bytes32 asset, uint amount) {
        uint abs = Spans.abs(cur);
        (account, asset, amount) = Blocks.unpackAccountAmount(abs);
        updated = Spans.advance(cur, Sizes.B96);
    }

    /// @notice Consume an ACCOUNT_AMOUNT form block and return its fields as a struct.
    // @param cur Cursor; advanced past the block.
    // @return value Decoded account, asset, and amount.
    function unpackAccountAmountValue(
        uint cur
    ) internal pure returns (uint updated, AccountAmount memory value) {
        (updated, value.account, value.asset, value.amount) = unpackAccountAmount(cur);
    }

    /// @notice Consume an ALLOCATION block and return its fields as separate values.
    // @param cur Cursor; advanced past the block.
    // @return host Host node ID.
    // @return asset Asset identifier.
    // @return amount Token amount.
    function unpackAllocation(uint cur) internal pure returns (uint updated, uint host, bytes32 asset, uint amount) {
        uint abs = Spans.abs(cur);
        (host, asset, amount) = Blocks.unpackAllocation(abs);
        updated = Spans.advance(cur, Sizes.HostAmount);
    }

    /// @notice Consume an ALLOCATION block and return its fields as a struct.
    // @param cur Cursor; advanced past the block.
    // @return value Decoded host, asset, and amount.
    function unpackAllocationValue(uint cur) internal pure returns (uint updated, HostAmount memory value) {
        (updated, value.host, value.asset, value.amount) = unpackAllocation(cur);
    }

    /// @notice Consume an ALLOWANCE block and return its fields as separate values.
    // @param cur Cursor; advanced past the block.
    // @return host Host node ID.
    // @return asset Asset identifier.
    // @return amount Token amount.
    function unpackAllowance(uint cur) internal pure returns (uint updated, uint host, bytes32 asset, uint amount) {
        uint abs = Spans.abs(cur);
        (host, asset, amount) = Blocks.unpackAllowance(abs);
        updated = Spans.advance(cur, Sizes.HostAmount);
    }

    /// @notice Consume an ALLOWANCE block and return its fields as a struct.
    // @param cur Cursor; advanced past the block.
    // @return value Decoded host, asset, and amount.
    function unpackAllowanceValue(uint cur) internal pure returns (uint updated, HostAmount memory value) {
        (updated, value.host, value.asset, value.amount) = unpackAllowance(cur);
    }

    /// @notice Consume a CUSTODY block and return its fields as separate values.
    // @param cur Cursor; advanced past the block.
    // @return host Host node ID.
    // @return asset Asset identifier.
    // @return amount Token amount.
    function unpackCustody(uint cur) internal pure returns (uint updated, uint host, bytes32 asset, uint amount) {
        uint abs = Spans.abs(cur);
        (host, asset, amount) = Blocks.unpackCustody(abs);
        updated = Spans.advance(cur, Sizes.HostAmount);
    }

    /// @notice Consume a CUSTODY block and return its fields as a struct.
    // @param cur Cursor; advanced past the block.
    // @return value Decoded host, asset, and amount.
    function unpackCustodyValue(uint cur) internal pure returns (uint updated, HostAmount memory value) {
        (updated, value.host, value.asset, value.amount) = unpackCustody(cur);
    }

    /// @notice Consume a TRANSACTION block and return its fields as separate values.
    // @param cur Cursor; advanced past the block.
    // @return from Source account identifier.
    // @return to Destination account identifier.
    // @return asset Asset identifier.
    // @return amount Token amount.
    function unpackTransaction(
        uint cur
    ) internal pure returns (uint updated, bytes32 from, bytes32 to, bytes32 asset, uint amount) {
        uint abs = Spans.abs(cur);
        (from, to, asset, amount) = Blocks.unpackTransaction(abs);
        updated = Spans.advance(cur, Sizes.Transaction);
    }

    /// @notice Consume a TRANSACTION block and return all fields as a struct.
    // @param cur Cursor; advanced past the block.
    // @return value Decoded from, to, asset, and amount.
    function unpackTxValue(uint cur) internal pure returns (uint updated, Tx memory value) {
        (updated, value.from, value.to, value.asset, value.amount) = unpackTransaction(cur);
    }

    // Type-specific dynamic decoders

    /// @notice Consume a STEP block and return its sub-command invocation fields.
    /// The `req` slice is the raw payload of the block's required BYTES child.
    // @param cur Cursor; advanced past the block.
    // @return target Destination node ID for the sub-command.
    // @return resources Packed resources assigned to the step.
    // @return req Embedded request bytes for the sub-command.
    function unpackStep(
        uint cur
    ) internal pure returns (uint updated, uint target, uint resources, bytes calldata req) {
        uint next;
        (target, resources, req, next) = Blocks.unpackStep(Spans.abs(cur));
        updated = Spans.seekAbs(cur, next);
    }

    /// @notice Consume a CALL block and return its target invocation fields.
    /// The `data` slice is the raw payload of the block's required BYTES child.
    // @param cur Cursor; advanced past the block.
    // @return target Target node ID to call.
    // @return resources Packed resources assigned to the call.
    // @return data Raw calldata payload for the target.
    function unpackCall(
        uint cur
    ) internal pure returns (uint updated, uint target, uint resources, bytes calldata data) {
        uint next;
        (target, resources, data, next) = Blocks.unpackCall(Spans.abs(cur));
        updated = Spans.seekAbs(cur, next);
    }

    /// @notice Consume a CONTEXT block and return its command context fields.
    /// The `state` and `request` slices are the raw payloads of the required BYTES children.
    // @param cur Cursor; advanced past the block.
    // @return account Command account identifier.
    // @return state Embedded state block stream.
    // @return request Embedded request block stream.
    function unpackContext(
        uint cur
    ) internal pure returns (uint updated, bytes32 account, bytes calldata state, bytes calldata request) {
        uint next;
        (account, state, request, next) = Blocks.unpackContext(Spans.abs(cur));
        updated = Spans.seekAbs(cur, next);
    }

    /// @notice Consume a RELAY block and return its destination portal, resources, and request stream.
    // @param cur Cursor; advanced past the block.
    // @return portal Destination portal identifier, often the destination host ID.
    // @return resources Chain-specific resources for the destination context.
    // @return request Embedded request block stream.
    function unpackRelay(
        uint cur
    ) internal pure returns (uint updated, uint portal, uint resources, bytes calldata request) {
        uint next;
        (portal, resources, request, next) = Blocks.unpackRelay(Spans.abs(cur));
        updated = Spans.seekAbs(cur, next);
    }

    /// @notice Consume a DISPATCH block and return its destination portal, resources, and payload.
    // @param cur Cursor; advanced past the block.
    // @return portal Destination portal identifier, often the destination host ID.
    // @return resources Chain-specific resources for the destination dispatch.
    // @return payload Encoded payload.
    function unpackDispatch(
        uint cur
    ) internal pure returns (uint updated, uint portal, uint resources, bytes calldata payload) {
        uint next;
        (portal, resources, payload, next) = Blocks.unpackDispatch(Spans.abs(cur));
        updated = Spans.seekAbs(cur, next);
    }

    /// @notice Consume a RECOVER block and return its handler, resources, key, and witness bytes.
    // @param cur Cursor; advanced past the block.
    // @return handler Recovery handler port node ID.
    // @return resources Packed resources assigned to the recovery attempt.
    // @return key Recovery lookup key.
    // @return witness Witness bytes used by the recovery handler.
    function unpackRecover(
        uint cur
    ) internal pure returns (uint updated, uint handler, uint resources, bytes32 key, bytes calldata witness) {
        uint next;
        (handler, resources, key, witness, next) = Blocks.unpackRecover(Spans.abs(cur));
        updated = Spans.seekAbs(cur, next);
    }

    // Type-specific validators

    /// @dev Validate an AUTH block using decoded cursor bounds.
    function expectAuth(
        uint offset,
        uint len,
        uint i,
        uint cid
    ) private pure returns (uint deadline, bytes calldata proof) {
        (uint abs, uint next) =
            expect(offset, len, i, 0, Keys.Auth, 64 + Sizes.Header + Sizes.Proof, 0);
        if (uint(bytes32(msg.data[abs:abs + 32])) != cid) revert UnexpectedValue();
        deadline = uint(bytes32(msg.data[abs + 32:abs + 64]));

        (abs, ) = expect(offset, len, i + Sizes.Header + 64, next, Keys.Bytes, Sizes.Proof, Sizes.Proof);
        proof = msg.data[abs:abs + Sizes.Proof];
    }

    /// @notice Validate an AUTH block at position `i` and extract deadline and proof.
    /// Does not advance the cursor.
    // @param cur Source cursor.
    // @param i Byte offset of the AUTH block.
    // @param cid Command ID that the AUTH block must reference.
    // @return deadline Expiry timestamp.
    // @return proof Raw proof bytes (layout: `[bytes20 signer][bytes65 sig]`).
    function expectAuth(uint cur, uint i, uint cid) internal pure returns (uint deadline, bytes calldata proof) {
        (, uint offset, uint len) = Spans.decode(cur);
        return expectAuth(offset, len, i, cid);
    }

    // -------------------------------------------------------------------------
    // require* - validate + advance (like consume with content checks)
    // -------------------------------------------------------------------------

    /// @notice Consume an asset block and assert it matches the expected asset.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected block specification.
    // @param asset Expected asset identifier.
    // @return amount Amount from the block.
    function requireAssetAmount(
        uint cur,
        uint spec,
        bytes32 asset
    ) internal pure returns (uint updated, uint amount) {
        bytes32 actual;
        bytes32 value;
        (updated, actual, value) = unpack64(cur, spec);
        if (actual != asset) revert UnexpectedValue();
        amount = uint(value);
    }

    /// @notice Consume an asset amount block, assert it matches the expected asset, and require the amount to be 1.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected block specification.
    // @param asset Expected asset identifier.
    function requireUnitAssetAmount(
        uint cur,
        uint spec,
        bytes32 asset
    ) internal pure returns (uint updated) {
        bytes32 actual;
        bytes32 value;
        (updated, actual, value) = unpack64(cur, spec);
        if (actual != asset) revert UnexpectedValue();
        if (uint(value) != 1) revert UnexpectedValue();
    }

    /// @notice Consume a host amount block and assert it matches the expected host.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected block specification.
    // @param host Expected host node ID.
    // @return asset Asset identifier from the block.
    // @return amount Amount from the block.
    function requireHostAmount(
        uint cur,
        uint spec,
        uint host
    ) internal pure returns (uint updated, bytes32 asset, uint amount) {
        bytes32 actualHost;
        bytes32 actualAsset;
        bytes32 value;
        (updated, actualHost, actualAsset, value) = unpack96(cur, spec);
        if (uint(actualHost) != host) revert UnexpectedValue();
        asset = actualAsset;
        amount = uint(value);
    }

    /// @notice Consume a host amount block and assert it matches the expected host and asset.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected block specification.
    // @param host Expected host node ID.
    // @param asset Expected asset identifier.
    // @return amount Amount from the block.
    function requireHostAmount(
        uint cur,
        uint spec,
        uint host,
        bytes32 asset
    ) internal pure returns (uint updated, uint amount) {
        bytes32 actualHost;
        bytes32 actualAsset;
        bytes32 value;
        (updated, actualHost, actualAsset, value) = unpack96(cur, spec);
        if (uint(actualHost) != host) revert UnexpectedValue();
        if (actualAsset != asset) revert UnexpectedValue();
        amount = uint(value);
    }

    /// @notice Consume a host amount block, assert it matches the expected host and asset, and require the amount to be 1.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected block specification.
    // @param host Expected host node ID.
    // @param asset Expected asset identifier.
    function requireUnitHostAmount(
        uint cur,
        uint spec,
        uint host,
        bytes32 asset
    ) internal pure returns (uint updated) {
        bytes32 actualHost;
        bytes32 actualAsset;
        bytes32 value;
        (updated, actualHost, actualAsset, value) = unpack96(cur, spec);
        if (uint(actualHost) != host) revert UnexpectedValue();
        if (actualAsset != asset) revert UnexpectedValue();
        if (uint(value) != 1) revert UnexpectedValue();
    }

    /// @notice Consume a host account asset block and assert it matches the expected host and account.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected block specification.
    // @param host Expected host node ID.
    // @param account Expected account identifier.
    // @return asset Asset identifier from the block.
    function requireHostAccountAsset(
        uint cur,
        uint spec,
        uint host,
        bytes32 account
    ) internal pure returns (uint updated, bytes32 asset) {
        bytes32 actualHost;
        bytes32 actualAccount;
        bytes32 actualAsset;
        (updated, actualHost, actualAccount, actualAsset) = unpack96(cur, spec);
        if (uint(actualHost) != host) revert UnexpectedValue();
        if (actualAccount != account) revert UnexpectedValue();
        asset = actualAsset;
    }

    /// @notice Consume a host account asset block, assert it targets the expected host, and return account and asset.
    // @param cur Cursor; advanced past the block.
    // @param spec Expected block specification.
    // @param host Expected host node ID.
    // @return account Account identifier from the block.
    // @return asset Asset identifier from the block.
    function requireHostAccountAsset(
        uint cur,
        uint spec,
        uint host
    ) internal pure returns (uint updated, bytes32 account, bytes32 asset) {
        bytes32 actualHost;
        bytes32 actualAccount;
        bytes32 actualAsset;
        (updated, actualHost, actualAccount, actualAsset) = unpack96(cur, spec);
        if (uint(actualHost) != host) revert UnexpectedValue();
        account = actualAccount;
        asset = actualAsset;
    }

    /// @notice Consume a HOST_ACCOUNT_ASSET form block, assert it targets the expected host, and return account and asset.
    // @param cur Cursor; advanced past the block.
    // @param host Expected host node ID.
    // @return account Account identifier from the block.
    // @return asset Asset identifier from the block.
    function requireHostAccountAsset(
        uint cur,
        uint host
    ) internal pure returns (uint updated, bytes32 account, bytes32 asset) {
        uint actual;
        (updated, actual, account, asset) = unpackHostAccountAsset(cur);
        if (actual != host) revert UnexpectedValue();
    }

    /// @notice Consume an AUTH block at the current position and verify the command ID.
    // @param cur Cursor; advanced past the block.
    // @param cid Expected command ID.
    // @return deadline Expiry timestamp.
    // @return proof Raw proof bytes.
    function requireAuth(
        uint cur,
        uint cid
    ) internal pure returns (uint updated, uint deadline, bytes calldata proof) {
        (uint i, uint offset, uint len) = Spans.decode(cur);
        (deadline, proof) = expectAuth(offset, len, i, cid);
        updated = cur + Sizes.Auth;
    }

    // -------------------------------------------------------------------------
    // ensure* - validate constraint blocks against provided values
    // -------------------------------------------------------------------------

    /// @notice Consume a BALANCE_LIMIT block and assert all constraint fields match the provided balance.
    // @param cur Cursor; advanced past the block.
    // @param asset Expected asset identifier.
    // @param amount Amount that must fall within the encoded min/max range.
    function ensureBalanceLimit(uint cur, bytes32 asset, uint amount) internal pure returns (uint updated) {
        bytes32 actual;
        uint min;
        uint max;
        uint abs = Spans.abs(cur);
        (actual, min, max) = Blocks.unpackBalanceLimit(abs);
        updated = Spans.advance(cur, Sizes.BalanceLimit);
        if (actual != asset) revert UnexpectedValue();
        if (min > amount || max < amount) revert UnexpectedValue();
    }

    /// @notice Consume a CUSTODY_LIMIT block and assert all constraint fields match the provided custody.
    // @param cur Cursor; advanced past the block.
    // @param host Expected host node ID.
    // @param asset Expected asset identifier.
    // @param amount Amount that must fall within the encoded min/max range.
    function ensureCustodyLimit(
        uint cur,
        uint host,
        bytes32 asset,
        uint amount
    ) internal pure returns (uint updated) {
        uint actualHost;
        bytes32 actualAsset;
        uint min;
        uint max;
        uint abs = Spans.abs(cur);
        (actualHost, actualAsset, min, max) = Blocks.unpackCustodyLimit(abs);
        updated = Spans.advance(cur, Sizes.CustodyLimit);
        if (actualHost != host || actualAsset != asset) revert UnexpectedValue();
        if (min > amount || max < amount) revert UnexpectedValue();
    }

    // -------------------------------------------------------------------------
    // Transform helpers
    // -------------------------------------------------------------------------

    /// @notice Consume a BALANCE block and scope its amount to a host.
    // @param cur Cursor; advanced past the BALANCE block.
    // @param host Host node ID to attach to the decoded balance.
    // @return value Host-scoped balance amount.
    function unpackBalanceForHost(
        uint cur,
        uint host
    ) internal pure returns (uint updated, HostAmount memory value) {
        value.host = host;
        (updated, value.asset, value.amount) = unpackBalance(cur);
    }

    /// @notice Consume a RELAY block and encode its destination context payload.
    // @param cur Cursor; advanced past the RELAY block.
    // @param account Account identifier to embed in the destination context.
    // @param state State block stream to embed in the destination context.
    // @return portal Destination portal identifier, often the destination host ID.
    // @return resources Chain-specific resources assigned to the destination context.
    // @return context Encoded CONTEXT block containing `account`, `state`, and relay request.
    function relayToContext(
        uint cur,
        bytes32 account,
        bytes calldata state
    ) internal pure returns (uint updated, uint portal, uint resources, bytes memory context) {
        bytes calldata request;
        (updated, portal, resources, request) = unpackRelay(cur);
        context = Blocks.context(account, bytes(state), bytes(request));
    }

    // -------------------------------------------------------------------------
    // Search helpers
    // -------------------------------------------------------------------------

    /// @notice Look for a NODE block anywhere in a calldata source and return its value.
    /// Scans from the start of `source` to the end.
    // @param source Calldata block stream to search.
    // @param backup Value to return if no NODE block is found.
    // @return node Node ID from the NODE block, or `backup` if absent.
    function resolveNode(bytes calldata source, uint backup) internal pure returns (uint node) {
        uint cur = open(source);
        (, uint offset, uint len) = Spans.decode(cur);
        uint i = Blocks.find(offset, len, 0, Keys.Node);
        if (i == len) return backup;

        (uint abs, ) = expect(offset, len, i, 0, Keys.Node, 32, 32);
        return uint(bytes32(msg.data[abs:abs + 32]));
    }

    /// @notice Look for a NODE block anywhere in a calldata source and require a non-zero result.
    /// Scans from the start of `source` to the end.
    // @param source Calldata block stream to search.
    // @param backup Value to use if no NODE block is found.
    // @return node Node ID from the NODE block, or `backup` if absent.
    function resolveNodeOrRevert(bytes calldata source, uint backup) internal pure returns (uint node) {
        node = resolveNode(source, backup);
        if (node == 0) revert ZeroNode();
    }

    /// @notice Look for an ACCOUNT block anywhere in a calldata source and return its value.
    /// Scans from the start of `source` to the end.
    // @param source Calldata block stream to search.
    // @param backup Account to return if no ACCOUNT block is found.
    // @return account Account from the ACCOUNT block, or `backup` if absent.
    function resolveAccount(bytes calldata source, bytes32 backup) internal pure returns (bytes32 account) {
        uint cur = open(source);
        (, uint offset, uint len) = Spans.decode(cur);
        uint i = Blocks.find(offset, len, 0, Keys.Account);
        if (i == len) return backup;

        (uint abs, ) = expect(offset, len, i, 0, Keys.Account, 32, 32);
        return bytes32(msg.data[abs:abs + 32]);
    }

    // -------------------------------------------------------------------------
    // Cur memory adapters
    // -------------------------------------------------------------------------

    function openCur(bytes calldata source) internal pure returns (Cur memory cur) {
        cur.packed = open(source);
    }

    function openCur(bytes calldata source, uint i) internal pure returns (Cur memory cur) {
        cur.packed = open(source, i);
    }

    function init(
        bytes calldata source,
        uint group,
        uint expected
    ) internal pure returns (Cur memory cur, uint groups) {
        (cur.packed, groups) = initMeta(source, group, expected, 0);
    }

    function more(Cur memory cur) internal pure returns (bool) {
        return Spans.more(cur.packed);
    }

    function seek(Cur memory cur, uint i) internal pure returns (Cur memory) {
        cur.packed = Spans.seek(cur.packed, i);
        return cur;
    }

    function skip(Cur memory cur, uint n) internal pure returns (Cur memory) {
        cur.packed = Spans.advance(cur.packed, n);
        return cur;
    }

    function skipTo(Cur memory cur, uint i) internal pure returns (Cur memory) {
        cur.packed = skipTo(cur.packed, i);
        return cur;
    }

    function slice(Cur memory cur, uint from, uint to) internal pure returns (Cur memory out) {
        out.packed = Spans.slice(cur.packed, from, to, 0);
    }

    function raw(Cur memory cur) internal pure returns (bytes calldata) {
        return raw(cur.packed);
    }

    function raw(Cur memory cur, uint from, uint to) internal pure returns (bytes calldata) {
        return raw(cur.packed, from, to);
    }

    function hash(Cur memory cur, uint from, uint to) internal pure returns (bytes32) {
        return hash(cur.packed, from, to);
    }

    function peek(Cur memory cur, uint i) internal pure returns (bytes4 key, uint len) {
        return peek(cur.packed, i);
    }

    function past(Cur memory cur) internal pure returns (uint) {
        return past(cur.packed);
    }

    function hasAt(Cur memory cur, uint i, bytes4 key) internal pure returns (bool) {
        return hasAt(cur.packed, i, key);
    }

    function isAt(Cur memory cur, bytes4 key) internal pure returns (bool) {
        return isAt(cur.packed, key);
    }

    function enter(Cur memory cur, uint spec) internal pure returns (uint next) {
        (cur.packed, next) = enter(cur.packed, spec);
    }

    function expect(Cur memory cur, uint i, uint end, uint spec) internal pure returns (uint abs, uint next) {
        return expect(cur.packed, i, end, spec);
    }

    function consume(Cur memory cur, uint end, uint spec) internal pure returns (uint abs) {
        (cur.packed, abs) = consume(cur.packed, end, spec);
    }

    function run(Cur memory cur, uint i, bytes4 key) internal pure returns (uint total, uint next) {
        return run(cur.packed, i, key);
    }

    function scope(Cur memory cur, bytes4 key, uint group) internal pure returns (uint groups) {
        (cur.packed, groups) = scope(cur.packed, key, group);
    }

    function find(Cur memory cur, uint i, bytes4 key) internal pure returns (uint) {
        return find(cur.packed, i, key);
    }

    function find(Cur memory cur, bytes4 key) internal pure returns (uint) {
        return find(cur.packed, key);
    }

    function list(Cur memory cur) internal pure returns (Cur memory items) {
        (cur.packed, items.packed) = list(cur.packed);
    }

    function take(Cur memory cur, bytes4 key) internal pure returns (Cur memory out) {
        (cur.packed, out.packed) = take(cur.packed, key);
    }

    function maybeOnly(Cur memory cur, bytes4 key) internal pure returns (bool) {
        return maybeOnly(cur.packed, key);
    }

    function maybeTake(Cur memory cur, bytes4 key) internal pure returns (Cur memory out) {
        (cur.packed, out.packed) = maybeTake(cur.packed, key);
    }

    function ensureAt(Cur memory cur, uint pos) internal pure {
        Spans.expect(cur.packed, pos);
    }

    function complete(Cur memory cur) internal pure {
        complete(cur.packed);
    }

    function read(Cur memory cur, uint n) internal pure returns (bytes32 value) {
        (cur.packed, value) = read(cur.packed, n);
    }

    function read1(Cur memory cur) internal pure returns (bytes1 value) {
        (cur.packed, value) = read1(cur.packed);
    }

    function read2(Cur memory cur) internal pure returns (bytes2 value) {
        (cur.packed, value) = read2(cur.packed);
    }

    function read4(Cur memory cur) internal pure returns (bytes4 value) {
        (cur.packed, value) = read4(cur.packed);
    }

    function read8(Cur memory cur) internal pure returns (bytes8 value) {
        (cur.packed, value) = read8(cur.packed);
    }

    function read16(Cur memory cur) internal pure returns (bytes16 value) {
        (cur.packed, value) = read16(cur.packed);
    }

    function read32(Cur memory cur) internal pure returns (bytes32 value) {
        (cur.packed, value) = read32(cur.packed);
    }

    function readUint(Cur memory cur) internal pure returns (uint value) {
        (cur.packed, value) = readUint(cur.packed);
    }

    function read64(Cur memory cur) internal pure returns (bytes32 a, bytes32 b) {
        (cur.packed, a, b) = read64(cur.packed);
    }

    function read96(Cur memory cur) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        (cur.packed, a, b, c) = read96(cur.packed);
    }

    function require32(Cur memory cur, bytes32 expected) internal pure {
        cur.packed = require32(cur.packed, expected);
    }

    function unpackRaw(Cur memory cur, uint spec) internal pure returns (bytes calldata data) {
        (cur.packed, data) = unpackRaw(cur.packed, spec);
    }

    function unpackBytes(Cur memory cur) internal pure returns (bytes calldata data) {
        (cur.packed, data) = unpackBytes(cur.packed);
    }

    function unpackString(Cur memory cur) internal pure returns (string memory data) {
        (cur.packed, data) = unpackString(cur.packed);
    }

    function unpackLabel(Cur memory cur) internal pure returns (uint id, bytes32 namespace, string memory name) {
        (cur.packed, id, namespace, name) = unpackLabel(cur.packed);
    }

    function unpackSchema(Cur memory cur) internal pure returns (uint spec, string memory body, bytes32 name) {
        (cur.packed, spec, body, name) = unpackSchema(cur.packed);
    }

    function unpack32(Cur memory cur, uint spec) internal pure returns (bytes32 value) {
        (cur.packed, value) = unpack32(cur.packed, spec);
    }

    function unpack64(Cur memory cur, uint spec) internal pure returns (bytes32 a, bytes32 b) {
        (cur.packed, a, b) = unpack64(cur.packed, spec);
    }

    function unpack96(Cur memory cur, uint spec) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        (cur.packed, a, b, c) = unpack96(cur.packed, spec);
    }

    function unpack128(
        Cur memory cur,
        uint spec
    ) internal pure returns (bytes32 a, bytes32 b, bytes32 c, bytes32 d) {
        (cur.packed, a, b, c, d) = unpack128(cur.packed, spec);
    }

    function unpack160(
        Cur memory cur,
        uint spec
    ) internal pure returns (bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e) {
        (cur.packed, a, b, c, d, e) = unpack160(cur.packed, spec);
    }

    function unpackAssetAmount(
        Cur memory cur,
        uint spec
    ) internal pure returns (bytes32 asset, uint amount) {
        (cur.packed, asset, amount) = unpackAssetAmount(cur.packed, spec);
    }

    function unpackAccountAmount(
        Cur memory cur,
        uint spec
    ) internal pure returns (bytes32 account, bytes32 asset, uint amount) {
        (cur.packed, account, asset, amount) = unpackAccountAmount(cur.packed, spec);
    }

    function unpackHostAmount(
        Cur memory cur,
        uint spec
    ) internal pure returns (uint host, bytes32 asset, uint amount) {
        (cur.packed, host, asset, amount) = unpackHostAmount(cur.packed, spec);
    }

    function unpackHostAccountAsset(
        Cur memory cur,
        uint spec
    ) internal pure returns (uint host, bytes32 account, bytes32 asset) {
        (cur.packed, host, account, asset) = unpackHostAccountAsset(cur.packed, spec);
    }

    function unpackTransaction(
        Cur memory cur,
        uint spec
    ) internal pure returns (bytes32 from, bytes32 to, bytes32 asset, uint amount) {
        (cur.packed, from, to, asset, amount) = unpackTransaction(cur.packed, spec);
    }

    function unpackAccount(Cur memory cur) internal pure returns (bytes32 account) {
        (cur.packed, account) = unpackAccount(cur.packed);
    }

    function unpackNode(Cur memory cur) internal pure returns (uint node) {
        (cur.packed, node) = unpackNode(cur.packed);
    }

    function unpackFee(Cur memory cur) internal pure returns (uint amount) {
        (cur.packed, amount) = unpackFee(cur.packed);
    }

    function unpackAsset(Cur memory cur) internal pure returns (bytes32 asset) {
        (cur.packed, asset) = unpackAsset(cur.packed);
    }

    function unpackAccountAsset(Cur memory cur) internal pure returns (bytes32 account, bytes32 asset) {
        (cur.packed, account, asset) = unpackAccountAsset(cur.packed);
    }

    function unpackAccountAssetValue(Cur memory cur) internal pure returns (AccountAsset memory value) {
        (cur.packed, value) = unpackAccountAssetValue(cur.packed);
    }

    function unpackBounty(Cur memory cur) internal pure returns (uint amount, bytes32 relayer) {
        (cur.packed, amount, relayer) = unpackBounty(cur.packed);
    }

    function unpackAmount(Cur memory cur) internal pure returns (bytes32 asset, uint amount) {
        (cur.packed, asset, amount) = unpackAmount(cur.packed);
    }

    function unpackAmountValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        (cur.packed, value) = unpackAmountValue(cur.packed);
    }

    function unpackBalance(Cur memory cur) internal pure returns (bytes32 asset, uint amount) {
        (cur.packed, asset, amount) = unpackBalance(cur.packed);
    }

    function unpackBalanceValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        (cur.packed, value) = unpackBalanceValue(cur.packed);
    }

    function unpackHostAccountAsset(
        Cur memory cur
    ) internal pure returns (uint host, bytes32 account, bytes32 asset) {
        (cur.packed, host, account, asset) = unpackHostAccountAsset(cur.packed);
    }

    function unpackHostAccountAssetValue(Cur memory cur) internal pure returns (HostAccountAsset memory value) {
        (cur.packed, value) = unpackHostAccountAssetValue(cur.packed);
    }

    function unpackAccountAmount(
        Cur memory cur
    ) internal pure returns (bytes32 account, bytes32 asset, uint amount) {
        (cur.packed, account, asset, amount) = unpackAccountAmount(cur.packed);
    }

    function unpackAccountAmountValue(Cur memory cur) internal pure returns (AccountAmount memory value) {
        (cur.packed, value) = unpackAccountAmountValue(cur.packed);
    }

    function unpackAllocation(Cur memory cur) internal pure returns (uint host, bytes32 asset, uint amount) {
        (cur.packed, host, asset, amount) = unpackAllocation(cur.packed);
    }

    function unpackAllocationValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        (cur.packed, value) = unpackAllocationValue(cur.packed);
    }

    function unpackAllowance(Cur memory cur) internal pure returns (uint host, bytes32 asset, uint amount) {
        (cur.packed, host, asset, amount) = unpackAllowance(cur.packed);
    }

    function unpackAllowanceValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        (cur.packed, value) = unpackAllowanceValue(cur.packed);
    }

    function unpackCustody(Cur memory cur) internal pure returns (uint host, bytes32 asset, uint amount) {
        (cur.packed, host, asset, amount) = unpackCustody(cur.packed);
    }

    function unpackCustodyValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        (cur.packed, value) = unpackCustodyValue(cur.packed);
    }

    function unpackTransaction(
        Cur memory cur
    ) internal pure returns (bytes32 from, bytes32 to, bytes32 asset, uint amount) {
        (cur.packed, from, to, asset, amount) = unpackTransaction(cur.packed);
    }

    function unpackTxValue(Cur memory cur) internal pure returns (Tx memory value) {
        (cur.packed, value) = unpackTxValue(cur.packed);
    }

    function unpackStep(
        Cur memory cur
    ) internal pure returns (uint target, uint resources, bytes calldata req) {
        (cur.packed, target, resources, req) = unpackStep(cur.packed);
    }

    function unpackCall(
        Cur memory cur
    ) internal pure returns (uint target, uint resources, bytes calldata data) {
        (cur.packed, target, resources, data) = unpackCall(cur.packed);
    }

    function unpackContext(
        Cur memory cur
    ) internal pure returns (bytes32 account, bytes calldata state, bytes calldata request) {
        (cur.packed, account, state, request) = unpackContext(cur.packed);
    }

    function unpackRelay(
        Cur memory cur
    ) internal pure returns (uint portal, uint resources, bytes calldata request) {
        (cur.packed, portal, resources, request) = unpackRelay(cur.packed);
    }

    function unpackDispatch(
        Cur memory cur
    ) internal pure returns (uint portal, uint resources, bytes calldata payload) {
        (cur.packed, portal, resources, payload) = unpackDispatch(cur.packed);
    }

    function unpackRecover(
        Cur memory cur
    ) internal pure returns (uint handler, uint resources, bytes32 key, bytes calldata witness) {
        (cur.packed, handler, resources, key, witness) = unpackRecover(cur.packed);
    }

    function expectAuth(
        Cur memory cur,
        uint i,
        uint cid
    ) internal pure returns (uint deadline, bytes calldata proof) {
        return expectAuth(cur.packed, i, cid);
    }

    function requireAssetAmount(Cur memory cur, uint spec, bytes32 asset) internal pure returns (uint amount) {
        (cur.packed, amount) = requireAssetAmount(cur.packed, spec, asset);
    }

    function requireUnitAssetAmount(Cur memory cur, uint spec, bytes32 asset) internal pure {
        cur.packed = requireUnitAssetAmount(cur.packed, spec, asset);
    }

    function requireHostAmount(
        Cur memory cur,
        uint spec,
        uint host
    ) internal pure returns (bytes32 asset, uint amount) {
        (cur.packed, asset, amount) = requireHostAmount(cur.packed, spec, host);
    }

    function requireHostAmount(
        Cur memory cur,
        uint spec,
        uint host,
        bytes32 asset
    ) internal pure returns (uint amount) {
        (cur.packed, amount) = requireHostAmount(cur.packed, spec, host, asset);
    }

    function requireUnitHostAmount(Cur memory cur, uint spec, uint host, bytes32 asset) internal pure {
        cur.packed = requireUnitHostAmount(cur.packed, spec, host, asset);
    }

    function requireHostAccountAsset(
        Cur memory cur,
        uint spec,
        uint host,
        bytes32 account
    ) internal pure returns (bytes32 asset) {
        (cur.packed, asset) = requireHostAccountAsset(cur.packed, spec, host, account);
    }

    function requireHostAccountAsset(
        Cur memory cur,
        uint spec,
        uint host
    ) internal pure returns (bytes32 account, bytes32 asset) {
        (cur.packed, account, asset) = requireHostAccountAsset(cur.packed, spec, host);
    }

    function requireHostAccountAsset(
        Cur memory cur,
        uint host
    ) internal pure returns (bytes32 account, bytes32 asset) {
        (cur.packed, account, asset) = requireHostAccountAsset(cur.packed, host);
    }

    function requireAuth(
        Cur memory cur,
        uint cid
    ) internal pure returns (uint deadline, bytes calldata proof) {
        (cur.packed, deadline, proof) = requireAuth(cur.packed, cid);
    }

    function ensureBalanceLimit(Cur memory cur, bytes32 asset, uint amount) internal pure {
        cur.packed = ensureBalanceLimit(cur.packed, asset, amount);
    }

    function ensureCustodyLimit(Cur memory cur, uint host, bytes32 asset, uint amount) internal pure {
        cur.packed = ensureCustodyLimit(cur.packed, host, asset, amount);
    }

    function unpackBalanceForHost(Cur memory cur, uint host) internal pure returns (HostAmount memory value) {
        (cur.packed, value) = unpackBalanceForHost(cur.packed, host);
    }

    function relayToContext(
        Cur memory cur,
        bytes32 account,
        bytes calldata state
    ) internal pure returns (uint portal, uint resources, bytes memory context) {
        (cur.packed, portal, resources, context) = relayToContext(cur.packed, account, state);
    }
}
