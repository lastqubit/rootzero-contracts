// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AssetAmount, AccountAsset, AccountAmount, HostAmount, HostAccountAsset, Tx} from "../core/Types.sol";
import {Sizes} from "./Schema.sol";
import {Keys} from "./Keys.sol";
import {ALLOC_SCALE, Writer, Writers} from "./Writers.sol";

/// @notice Zero-copy view into a calldata block stream.
/// All positions (`i`, `bound`) are byte offsets relative to the start of the source region.
/// The absolute calldata location of byte `i` is `offset + i`.
struct Cur {
    /// @dev Absolute calldata byte offset of the source region start.
    uint offset;
    /// @dev Current read position, relative to the source start.
    uint i;
    /// @dev Total byte length of the source region.
    uint len;
    /// @dev Exclusive upper bound for the current iteration group, set by `primeRun`.
    /// Zero until `primeRun` is called.
    uint bound;
}

using Cursors for Cur;

/// @title Cursors
/// @notice Calldata block stream parser for the rootzero protocol.
/// A `Cur` is a lightweight view into a slice of `msg.data`; no data is copied.
/// Blocks are encoded as `[bytes4 key][bytes4 payloadLen][payload]`.
library Cursors {
    /// @dev Source region contains a block whose declared length exceeds the region boundary,
    ///      or a header read would go out of bounds.
    error MalformedBlocks();
    /// @dev Current block key does not match the expected key, or payload size is out of range.
    error InvalidBlock();
    /// @dev `complete` called but the cursor has not consumed exactly up to `bound`.
    error IncompleteCursor();
    /// @dev `primeRun` found zero blocks of the expected key; the cursor region is empty.
    error ZeroCursor();
    /// @dev `primeRun` was called with a zero group size.
    error ZeroGroup();
    /// @dev An account field was required but the block or fallback was zero.
    error ZeroAccount();
    /// @dev A node field was required but the block or fallback was zero.
    error ZeroNode();
    /// @dev A field value did not match the expected value.
    error UnexpectedValue();
    /// @dev Input and output block counts are not proportional to their declared group sizes.
    error BadRatio();
    /// @dev A fixed-width low-level unpacker received an invalid final-word keep length.
    error InvalidKeep();

    // -------------------------------------------------------------------------
    // Cursor construction and navigation
    // -------------------------------------------------------------------------

    /// @notice Create a cursor backed by a calldata slice.
    /// @param source Calldata slice that forms the block stream.
    /// @return cur Cursor positioned at the beginning of `source`.
    function open(bytes calldata source) internal pure returns (Cur memory cur) {
        uint offset;
        // Extract the absolute calldata offset of `source` using inline assembly,
        // as Solidity does not expose this directly for calldata slices.
        assembly ("memory-safe") {
            offset := source.offset
        }
        cur.offset = offset;
        cur.len = source.length;
    }

    /// @notice Move the cursor to an absolute position within the source region.
    /// @param cur Cursor to update.
    /// @param i New read position (byte offset relative to source start).
    /// @return Updated cursor with `cur.i == i`.
    function seek(Cur memory cur, uint i) internal pure returns (Cur memory) {
        if (i > cur.len) revert MalformedBlocks();
        cur.i = i;
        return cur;
    }

    /// @notice Create a subcursor over the half-open range `[from, to)` within the source region.
    /// The returned cursor starts at position zero within that sliced region.
    /// @param cur Source cursor.
    /// @param from Start byte offset within the source region (inclusive).
    /// @param to End byte offset within the source region (exclusive).
    /// @return out Cursor scoped to the requested sub-range.
    function slice(Cur memory cur, uint from, uint to) internal pure returns (Cur memory out) {
        if (from > to || to > cur.len) revert MalformedBlocks();
        out.offset = cur.offset + from;
        out.len = to - from;
    }

    /// @notice Read a block header at position `i` without advancing the cursor.
    /// @param cur Source cursor.
    /// @param i Byte offset of the block header within the source region.
    /// @return key Four-byte block type identifier.
    /// @return len Payload byte length declared in the header.
    function peek(Cur memory cur, uint i) internal pure returns (bytes4 key, uint len) {
        if (i + 8 > cur.len) revert MalformedBlocks();
        uint abs = cur.offset + i;
        key = bytes4(msg.data[abs:abs + 4]);
        len = uint32(bytes4(msg.data[abs + 4:abs + 8]));
        if (i + 8 + len > cur.len) revert MalformedBlocks();
    }

    /// @notice Return the byte offset immediately past the block at the current cursor position.
    /// Does not advance the cursor.
    /// @param cur Source cursor.
    /// @return Byte offset immediately past the current block, relative to the source region.
    function past(Cur memory cur) internal pure returns (uint) {
        (, uint len) = peek(cur, cur.i);
        return cur.i + Sizes.Header + len;
    }

    /// @notice Return true if the current cursor position contains a block header with the given key.
    /// Returns false when `cur.i` is out of bounds or the key differs.
    /// @param cur Source cursor.
    /// @param key Expected block type identifier.
    /// @return Whether the block header at `cur.i` uses `key`.
    function has(Cur memory cur, bytes4 key) internal pure returns (bool) {
        if (cur.i + 8 > cur.len) return false;
        uint abs = cur.offset + cur.i;
        return bytes4(msg.data[abs:abs + 4]) == key;
    }

    /// @notice Validate a block at position `i` and return its payload location.
    /// Does not advance the cursor.
    /// @param cur Source cursor.
    /// @param i Byte offset of the block within the source region.
    /// @param key Expected block type key; reverts if actual key differs.
    /// @param min Minimum acceptable payload length (inclusive).
    /// @param max Maximum acceptable payload length (inclusive); 0 means unbounded.
    /// @return abs Absolute calldata offset of the payload start.
    /// @return next Byte offset of the block immediately following this one (relative to source start).
    function expect(
        Cur memory cur,
        uint i,
        bytes4 key,
        uint min,
        uint max
    ) internal pure returns (uint abs, uint next) {
        (bytes4 current, uint len) = peek(cur, i);
        if (current != key) revert InvalidBlock();
        abs = cur.offset + i + 8;
        next = i + 8 + len;
        if (len < min || (max != 0 && len > max)) revert InvalidBlock();
    }

    /// @notice Count consecutive blocks of the same key starting at `i`.
    /// @param cur Source cursor.
    /// @param i Starting byte offset within the source region.
    /// @param key Block type to count.
    /// @return total Number of consecutive matching blocks.
    /// @return next Byte offset immediately after the last counted block.
    function countRun(Cur memory cur, uint i, bytes4 key) internal pure returns (uint total, uint next) {
        next = i;
        while (next < cur.len) {
            (bytes4 current, uint len) = peek(cur, next);
            if (current != key) break;
            next += 8 + len;

            unchecked {
                ++total;
            }
        }
    }

    /// @notice Initialise the cursor for a grouped iteration pass.
    /// Reads the key of the first block, counts the consecutive run of that key,
    /// stores the run end in `cur.bound`, validates that the count is a
    /// multiple of `group`, and returns both the raw block count and the
    /// normalized quotient (`count / group`).
    /// @param cur Cursor to prime; `cur.bound` is updated in place.
    /// @param group Expected group size (e.g. 1 for single-asset, 2 for paired input/output).
    /// @return key Block type identifier of the run.
    /// @return count Total number of blocks in the run (always a multiple of `group`).
    /// @return quotient Number of groups represented by the run (`count / group`).
    function primeRun(Cur memory cur, uint group) internal pure returns (bytes4 key, uint count, uint quotient) {
        if (group == 0) revert ZeroGroup();
        key = cur.i + 4 > cur.len ? bytes4(0) : bytes4(msg.data[cur.offset + cur.i:cur.offset + cur.i + 4]);
        (count, cur.bound) = countRun(cur, cur.i, key);
        if (count == 0) revert ZeroCursor();
        if (count % group != 0) revert BadRatio();
        quotient = count / group;
    }

    /// @notice Scan forward from `i` for the first block matching `key`.
    /// @param cur Source cursor.
    /// @param i Starting byte offset for the search.
    /// @param key Block type to find.
    /// @return Byte offset of the matching block, or `cur.len` if not found.
    function find(Cur memory cur, uint i, bytes4 key) internal pure returns (uint) {
        while (i < cur.len) {
            (bytes4 current, uint len) = peek(cur, i);
            if (current == key) return i;
            i += 8 + len;
        }
        return cur.len;
    }

    /// @notice Scan forward from the current position for the first block matching `key`.
    /// @param cur Source cursor.
    /// @param key Block type to find.
    /// @return Byte offset of the matching block, or `cur.len` if not found.
    function find(Cur memory cur, bytes4 key) internal pure returns (uint) {
        return find(cur, cur.i, key);
    }

    /// @notice Validate and consume the current block, advancing `cur.i` past it.
    /// @param cur Cursor to advance.
    /// @param key Expected block type key.
    /// @param min Minimum payload length.
    /// @param max Maximum payload length (0 = unbounded).
    /// @return abs Absolute calldata offset of the payload start.
    function consume(Cur memory cur, bytes4 key, uint min, uint max) internal pure returns (uint abs) {
        uint next;
        (abs, next) = expect(cur, cur.i, key, min, max);
        cur.i = next;
    }

    /// @notice Load a payload word and mask away any omitted tail bytes on the right.
    /// @param abs Absolute calldata offset of the word start.
    /// @param tail Number of trailing bytes omitted from the logical payload (0..31).
    /// @return value Decoded word with omitted tail bytes zeroed.
    function mask(uint abs, uint tail) internal pure returns (bytes32 value) {
        assembly ("memory-safe") {
            value := calldataload(abs)
        }
        if (tail != 0) value &= bytes32(type(uint256).max << (tail * 8));
    }

    /// @notice Enter a Bundle block at the current position and return the next offset.
    /// Advances `cur.i` past the bundle header so the bundled members can be parsed
    /// directly from the same cursor. The returned `next` is the byte offset
    /// immediately after the bundle payload, relative to the current cursor region.
    /// @param cur Cursor positioned at a bundle block; advanced past the 8-byte header.
    /// @return next Byte offset immediately after the bundle payload.
    function bundle(Cur memory cur) internal pure returns (uint next) {
        (, next) = expect(cur, cur.i, Keys.Bundle, 0, 0);
        cur.i += 8;
    }

    /// @notice Enter a List block at the current position and return the next offset.
    /// Advances `cur.i` past the list header so the list members can be parsed
    /// directly from the same cursor. The returned `next` is the byte offset
    /// immediately after the list payload, relative to the current cursor region.
    /// @param cur Cursor positioned at a list block; advanced past the 8-byte header.
    /// @return next Byte offset immediately after the list payload.
    function list(Cur memory cur) internal pure returns (uint next) {
        (, next) = expect(cur, cur.i, Keys.List, 0, 0);
        cur.i += 8;
    }

    /// @notice Consume a block with the given key at the current position and return a cursor over the full block slice.
    /// Advances `cur.i` past the block while the returned cursor is scoped to the
    /// full block bytes as a fresh zero-based region.
    /// @param cur Cursor positioned at the expected block.
    /// @param key Expected block type key.
    /// @return out Cursor scoped to the full block.
    function take(Cur memory cur, bytes4 key) internal pure returns (Cur memory out) {
        (, uint next) = expect(cur, cur.i, key, 0, 0);
        out = cur.slice(cur.i, next);
        cur.i = next;
    }

    /// @notice Consume an optional ROUTE block at the current position and return a cursor over the full block slice.
    /// If the current block is not ROUTE, returns an empty cursor and leaves `cur.i` unchanged.
    /// Otherwise behaves like `take(cur, Keys.Route)`.
    /// @param cur Cursor positioned at an optional ROUTE block.
    /// @return out Cursor scoped to the full ROUTE block, or empty when no ROUTE block is present.
    function maybeRoute(Cur memory cur) internal pure returns (Cur memory out) {
        return cur.has(Keys.Route) ? take(cur, Keys.Route) : cur.slice(cur.i, cur.i);
    }

    /// @notice Enter a List block, prime its member run, and return the raw block count.
    /// @param cur Cursor positioned at a list block; advanced past the 8-byte header.
    /// @param group Expected block group size for the list item stream.
    /// @return count Total number of blocks in the list payload (a multiple of `group`).
    /// @return next Byte offset immediately after the list payload.
    function list(Cur memory cur, uint group) internal pure returns (uint count, uint next) {
        next = list(cur);
        (, count, ) = cur.primeRun(group);
        if (cur.bound != next) revert IncompleteCursor();
    }

    /// @notice Assert that the cursor has consumed exactly up to `bound`.
    /// Reverts with `IncompleteCursor` if `bound` is zero or `cur.i != cur.bound`.
    /// @param cur Cursor to check.
    function complete(Cur memory cur) internal pure {
        if (cur.bound == 0 || cur.i != cur.bound) revert IncompleteCursor();
    }

    /// @notice Assert that the cursor has consumed its entire source region.
    /// Reverts with `IncompleteCursor` when `cur.i != cur.len`.
    /// @param cur Cursor to check.
    function end(Cur memory cur) internal pure {
        if (cur.i != cur.len) revert IncompleteCursor();
    }

    /// @notice Resume parsing after a nested region delimited by `resumeAt`.
    /// Reverts with `IncompleteCursor` if `cur.i` has advanced past `resumeAt` or `resumeAt`
    /// exceeds the cursor region length. Otherwise moves `cur.i` to `end`.
    /// @param cur Cursor to advance.
    /// @param resumeAt Relative end offset of the nested region to resume after.
    function resume(Cur memory cur, uint resumeAt) internal pure {
        if (resumeAt > cur.len || cur.i > resumeAt) revert IncompleteCursor();
        cur.i = resumeAt;
    }

    /// @notice Ensure that parsing has reached an exact nested-region boundary.
    /// Reverts with `IncompleteCursor` if `ensureAt` exceeds the cursor region length
    /// or `cur.i != ensureAt`.
    /// @param cur Cursor to check.
    /// @param ensureAt Relative offset that `cur.i` must match exactly.
    function ensure(Cur memory cur, uint ensureAt) internal pure {
        if (ensureAt > cur.len || cur.i != ensureAt) revert IncompleteCursor();
    }

    /// @notice Assert completion and finalise a writer in one step.
    /// @param cur Cursor to check.
    /// @param writer Writer to finalise.
    /// @return Trimmed output bytes from the writer.
    function complete(Cur memory cur, Writer memory writer) internal pure returns (bytes memory) {
        if (cur.bound == 0 || cur.i != cur.bound) revert IncompleteCursor();
        return Writers.finish(writer);
    }

    // -------------------------------------------------------------------------
    // Block factory helpers
    // -------------------------------------------------------------------------

    /// @notice Encode a block with a single 32-byte payload word.
    /// @param key Block type key.
    /// @param value 32-byte payload.
    /// @return Encoded block bytes.
    function createBlock32(bytes4 key, bytes32 value) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x20)), value);
    }

    /// @notice Encode a block with two 32-byte payload words (64-byte payload).
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @return Encoded block bytes.
    function createBlock64(bytes4 key, bytes32 a, bytes32 b) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x40)), a, b);
    }

    /// @notice Encode a block with three 32-byte payload words (96-byte payload).
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @return Encoded block bytes.
    function createBlock96(bytes4 key, bytes32 a, bytes32 b, bytes32 c) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x60)), a, b, c);
    }

    /// @notice Encode a block with four 32-byte payload words (128-byte payload).
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @return Encoded block bytes.
    function createBlock128(
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d
    ) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x80)), a, b, c, d);
    }

    /// @notice Encode a block with five 32-byte payload words (160-byte payload).
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @param e Fifth payload word.
    /// @return Encoded block bytes.
    function createBlock160(
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        bytes32 e
    ) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0xa0)), a, b, c, d, e);
    }

    /// @notice Encode a block with a 32-byte fixed head followed by a variable-length tail.
    /// @param key Block type key.
    /// @param head Fixed 32-byte head payload.
    /// @param tail Variable-length payload bytes appended after the head.
    /// @return Encoded block bytes.
    function createBlockHead32(bytes4 key, bytes32 head, bytes memory tail) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x20 + tail.length)), head, tail);
    }

    /// @notice Encode a block with a 64-byte fixed head followed by a variable-length tail.
    /// @param key Block type key.
    /// @param a First fixed payload word.
    /// @param b Second fixed payload word.
    /// @param tail Variable-length payload bytes appended after the fixed head.
    /// @return Encoded block bytes.
    function createBlockHead64(
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes memory tail
    ) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x40 + tail.length)), a, b, tail);
    }

    /// @notice Encode a BOUNTY block.
    /// @param bounty Relayer reward amount.
    /// @param relayer Relayer account identifier.
    /// @return Encoded BOUNTY block bytes.
    function toBountyBlock(uint bounty, bytes32 relayer) internal pure returns (bytes memory) {
        return createBlock64(Keys.Bounty, bytes32(bounty), relayer);
    }

    /// @notice Encode a STEP block.
    /// @param target Command target identifier.
    /// @param value Native value forwarded with the step.
    /// @param request Variable-length nested request payload.
    /// @return Encoded STEP block bytes.
    function toStepBlock(uint target, uint value, bytes memory request) internal pure returns (bytes memory) {
        return createBlockHead64(Keys.Step, bytes32(target), bytes32(value), request);
    }

    /// @notice Encode a CALL block.
    /// @param target Target node identifier.
    /// @param value Native value forwarded with the call.
    /// @param data Raw calldata payload for the target.
    /// @return Encoded CALL block bytes.
    function toCallBlock(uint target, uint value, bytes memory data) internal pure returns (bytes memory) {
        return createBlockHead64(Keys.Call, bytes32(target), bytes32(value), data);
    }

    /// @notice Encode a BALANCE block.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    /// @return Encoded BALANCE block bytes.
    function toBalanceBlock(bytes32 asset, bytes32 meta, uint amount) internal pure returns (bytes memory) {
        return createBlock96(Keys.Balance, asset, meta, bytes32(amount));
    }

    /// @notice Encode a CUSTODY block.
    /// @param host Host node ID holding the custody.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    /// @return Encoded CUSTODY block bytes.
    function toCustodyBlock(
        uint host,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) internal pure returns (bytes memory) {
        return createBlock128(Keys.Custody, bytes32(host), asset, meta, bytes32(amount));
    }

    // -------------------------------------------------------------------------
    // Raw calldata loaders
    // -------------------------------------------------------------------------

    /// @notice Load one 32-byte word from calldata.
    /// @dev Performs no bounds, key, length, or cursor checks.
    /// @param abs Absolute calldata offset of the word start.
    /// @return a Loaded word.
    function load32(uint abs) internal pure returns (bytes32 a) {
        assembly ("memory-safe") {
            a := calldataload(abs)
        }
    }

    /// @notice Load two 32-byte words from calldata.
    /// @dev Performs no bounds, key, length, or cursor checks.
    /// @param abs Absolute calldata offset of the first word.
    /// @return a First loaded word.
    /// @return b Second loaded word.
    function load64(uint abs) internal pure returns (bytes32 a, bytes32 b) {
        assembly ("memory-safe") {
            a := calldataload(abs)
            b := calldataload(add(abs, 0x20))
        }
    }

    /// @notice Load three 32-byte words from calldata.
    /// @dev Performs no bounds, key, length, or cursor checks.
    /// @param abs Absolute calldata offset of the first word.
    /// @return a First loaded word.
    /// @return b Second loaded word.
    /// @return c Third loaded word.
    function load96(uint abs) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        assembly ("memory-safe") {
            a := calldataload(abs)
            b := calldataload(add(abs, 0x20))
            c := calldataload(add(abs, 0x40))
        }
    }

    /// @notice Load four 32-byte words from calldata.
    /// @dev Performs no bounds, key, length, or cursor checks.
    /// @param abs Absolute calldata offset of the first word.
    /// @return a First loaded word.
    /// @return b Second loaded word.
    /// @return c Third loaded word.
    /// @return d Fourth loaded word.
    function load128(uint abs) internal pure returns (bytes32 a, bytes32 b, bytes32 c, bytes32 d) {
        assembly ("memory-safe") {
            a := calldataload(abs)
            b := calldataload(add(abs, 0x20))
            c := calldataload(add(abs, 0x40))
            d := calldataload(add(abs, 0x60))
        }
    }

    /// @notice Load five 32-byte words from calldata.
    /// @dev Performs no bounds, key, length, or cursor checks.
    /// @param abs Absolute calldata offset of the first word.
    /// @return a First loaded word.
    /// @return b Second loaded word.
    /// @return c Third loaded word.
    /// @return d Fourth loaded word.
    /// @return e Fifth loaded word.
    function load160(uint abs) internal pure returns (bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e) {
        assembly ("memory-safe") {
            a := calldataload(abs)
            b := calldataload(add(abs, 0x20))
            c := calldataload(add(abs, 0x40))
            d := calldataload(add(abs, 0x60))
            e := calldataload(add(abs, 0x80))
        }
    }

    // -------------------------------------------------------------------------
    // unpack* - consume current block and decode payload fields
    // -------------------------------------------------------------------------

    // Generic fixed-width decoders

    /// @notice Consume a dynamic block with the given key and return the raw payload as a calldata slice.
    /// The payload length is variable; the returned slice covers the entire payload.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return data Raw block payload bytes.
    function unpackRaw(Cur memory cur, bytes4 key) internal pure returns (bytes calldata data) {
        (uint abs, uint next) = expect(cur, cur.i, key, 0, 0);
        data = msg.data[abs:cur.offset + next];
        cur.i = next;
    }

    /// @notice Consume a dynamic block with a single bytes32 payload.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return value Decoded bytes32.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function unpack32(Cur memory cur, bytes4 key, uint keep) internal pure returns (bytes32 value) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        uint len = keep;
        uint abs = consume(cur, key, len, len);
        value = mask(abs, 32 - keep);
    }

    /// @notice Consume a dynamic block with two bytes32 payload words.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function unpack64(Cur memory cur, bytes4 key, uint keep) internal pure returns (bytes32 a, bytes32 b) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        uint len = 32 + keep;
        uint abs = consume(cur, key, len, len);
        a = bytes32(msg.data[abs:abs + 32]);
        b = mask(abs + 32, 32 - keep);
    }

    /// @notice Consume a dynamic block with three bytes32 payload words.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    /// @return c Third decoded bytes32.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function unpack96(Cur memory cur, bytes4 key, uint keep) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        uint len = 64 + keep;
        uint abs = consume(cur, key, len, len);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = mask(abs + 64, 32 - keep);
    }

    /// @notice Consume a dynamic block with a 128-byte payload (four 32-byte words).
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    /// @return c Third decoded bytes32.
    /// @return d Fourth decoded bytes32.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function unpack128(
        Cur memory cur,
        bytes4 key,
        uint keep
    ) internal pure returns (bytes32 a, bytes32 b, bytes32 c, bytes32 d) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        uint len = 96 + keep;
        uint abs = consume(cur, key, len, len);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
        d = mask(abs + 96, 32 - keep);
    }

    /// @notice Consume a dynamic block with a 160-byte payload (five 32-byte words).
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    /// @return c Third decoded bytes32.
    /// @return d Fourth decoded bytes32.
    /// @return e Fifth decoded bytes32.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function unpack160(
        Cur memory cur,
        bytes4 key,
        uint keep
    ) internal pure returns (bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        uint len = 128 + keep;
        uint abs = consume(cur, key, len, len);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
        d = bytes32(msg.data[abs + 96:abs + 128]);
        e = mask(abs + 128, 32 - keep);
    }

    /// @notice Consume a dynamic block with a single uint payload.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return value Decoded uint value.
    function unpackUint(Cur memory cur, bytes4 key) internal pure returns (uint value) {
        value = uint(unpack32(cur, key, 32));
    }

    /// @notice Consume a dynamic block with two uint payload words.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First decoded uint.
    /// @return b Second decoded uint.
    function unpack2Uint(Cur memory cur, bytes4 key) internal pure returns (uint a, uint b) {
        (bytes32 x, bytes32 y) = unpack64(cur, key, 32);
        return (uint(x), uint(y));
    }

    /// @notice Consume a dynamic block with three uint payload words.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First decoded uint.
    /// @return b Second decoded uint.
    /// @return c Third decoded uint.
    function unpack3Uint(Cur memory cur, bytes4 key) internal pure returns (uint a, uint b, uint c) {
        (bytes32 x, bytes32 y, bytes32 z) = unpack96(cur, key, 32);
        return (uint(x), uint(y), uint(z));
    }

    // Generic fixed-head decoders

    /// @notice Consume a dynamic block with a 32-byte fixed head followed by a variable-length tail.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return head Fixed 32-byte head.
    /// @return tail Variable-length payload bytes after the fixed head.
    function unpackHead32(Cur memory cur, bytes4 key) internal pure returns (bytes32 head, bytes calldata tail) {
        uint abs = consume(cur, key, 32, 0);
        head = bytes32(msg.data[abs:abs + 32]);
        tail = msg.data[abs + 32:cur.offset + cur.i];
    }

    /// @notice Consume a dynamic block with a 64-byte fixed head followed by a variable-length tail.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First fixed head word.
    /// @return b Second fixed head word.
    /// @return tail Variable-length payload bytes after the fixed head.
    function unpackHead64(
        Cur memory cur,
        bytes4 key
    ) internal pure returns (bytes32 a, bytes32 b, bytes calldata tail) {
        uint abs = consume(cur, key, 64, 0);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        tail = msg.data[abs + 64:cur.offset + cur.i];
    }

    /// @notice Consume a dynamic block with a 96-byte fixed head followed by a variable-length tail.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First fixed head word.
    /// @return b Second fixed head word.
    /// @return c Third fixed head word.
    /// @return tail Variable-length payload bytes after the fixed head.
    function unpackHead96(
        Cur memory cur,
        bytes4 key
    ) internal pure returns (bytes32 a, bytes32 b, bytes32 c, bytes calldata tail) {
        uint abs = consume(cur, key, 96, 0);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
        tail = msg.data[abs + 96:cur.offset + cur.i];
    }

    /// @notice Consume a dynamic block with a 128-byte fixed head followed by a variable-length tail.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First fixed head word.
    /// @return b Second fixed head word.
    /// @return c Third fixed head word.
    /// @return d Fourth fixed head word.
    /// @return tail Variable-length payload bytes after the fixed head.
    function unpackHead128(
        Cur memory cur,
        bytes4 key
    ) internal pure returns (bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes calldata tail) {
        uint abs = consume(cur, key, 128, 0);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
        d = bytes32(msg.data[abs + 96:abs + 128]);
        tail = msg.data[abs + 128:cur.offset + cur.i];
    }

    // Generic typed-shape decoders

    /// @notice Consume a fixed-size asset amount block and return asset, meta, and amount.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block key.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Scalar amount value.
    function unpackAssetAmount(
        Cur memory cur,
        bytes4 key
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, key, 96, 96);
        asset = bytes32(msg.data[abs:abs + 32]);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume a fixed-size account amount block and return account, asset, meta, and amount.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block key.
    /// @return account Account identifier.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Scalar amount value.
    function unpackAccountAmount(
        Cur memory cur,
        bytes4 key
    ) internal pure returns (bytes32 account, bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, key, 128, 128);
        account = bytes32(msg.data[abs:abs + 32]);
        asset = bytes32(msg.data[abs + 32:abs + 64]);
        meta = bytes32(msg.data[abs + 64:abs + 96]);
        amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    /// @notice Consume a fixed-size host amount block and return host, asset, meta, and amount.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block key.
    /// @return host Host node ID.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Scalar amount value.
    function unpackHostAmount(
        Cur memory cur,
        bytes4 key
    ) internal pure returns (uint host, bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, key, 128, 128);
        host = uint(bytes32(msg.data[abs:abs + 32]));
        asset = bytes32(msg.data[abs + 32:abs + 64]);
        meta = bytes32(msg.data[abs + 64:abs + 96]);
        amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    /// @notice Consume a fixed-size host account asset block and return host, account, asset, and meta.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block key.
    /// @return host Host node ID.
    /// @return account Account identifier.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    function unpackHostAccountAsset(
        Cur memory cur,
        bytes4 key
    ) internal pure returns (uint host, bytes32 account, bytes32 asset, bytes32 meta) {
        uint abs = consume(cur, key, 128, 128);
        host = uint(bytes32(msg.data[abs:abs + 32]));
        account = bytes32(msg.data[abs + 32:abs + 64]);
        asset = bytes32(msg.data[abs + 64:abs + 96]);
        meta = bytes32(msg.data[abs + 96:abs + 128]);
    }

    /// @notice Consume a fixed-size transaction block and return from, to, asset, meta, and amount.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block key.
    /// @return from Source account identifier.
    /// @return to Destination account identifier.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Scalar amount value.
    function unpackTransaction(
        Cur memory cur,
        bytes4 key
    ) internal pure returns (bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, key, 160, 160);
        from = bytes32(msg.data[abs:abs + 32]);
        to = bytes32(msg.data[abs + 32:abs + 64]);
        asset = bytes32(msg.data[abs + 64:abs + 96]);
        meta = bytes32(msg.data[abs + 96:abs + 128]);
        amount = uint(bytes32(msg.data[abs + 128:abs + 160]));
    }

    // Type-specific fixed-width decoders

    /// @notice Consume an ACCOUNT block and return the account.
    /// @param cur Cursor; advanced past the block.
    /// @return account Account identifier.
    function unpackAccount(Cur memory cur) internal pure returns (bytes32 account) {
        account = unpack32(cur, Keys.Account, 32);
    }

    /// @notice Consume a NODE block and return the node ID.
    /// @param cur Cursor; advanced past the block.
    /// @return node Node identifier.
    function unpackNode(Cur memory cur) internal pure returns (uint node) {
        node = uint(unpack32(cur, Keys.Node, 32));
    }

    /// @notice Consume a RATE block and return the value.
    /// @param cur Cursor; advanced past the block.
    /// @return value Encoded ratio or rate.
    function unpackRate(Cur memory cur) internal pure returns (uint value) {
        value = uint(unpack32(cur, Keys.Rate, 32));
    }

    /// @notice Consume a QUANTITY block and return the amount.
    /// @param cur Cursor; advanced past the block.
    /// @return amount Scalar quantity value.
    function unpackQuantity(Cur memory cur) internal pure returns (uint amount) {
        amount = uint(unpack32(cur, Keys.Quantity, 32));
    }

    /// @notice Consume a FEE block and return the amount.
    /// @param cur Cursor; advanced past the block.
    /// @return amount Fee amount.
    function unpackFee(Cur memory cur) internal pure returns (uint amount) {
        amount = uint(unpack32(cur, Keys.Fee, 32));
    }

    /// @notice Consume an ASSET block and return the asset descriptor fields.
    /// @param cur Cursor; advanced past the block.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    function unpackAsset(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta) {
        (asset, meta) = unpack64(cur, Keys.Asset, 32);
    }

    /// @notice Consume an ACCOUNT_ASSET form block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return account Account identifier.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    function unpackAccountAsset(Cur memory cur) internal pure returns (bytes32 account, bytes32 asset, bytes32 meta) {
        uint abs = consume(cur, Keys.AccountAsset, 96, 96);
        account = bytes32(msg.data[abs:abs + 32]);
        asset = bytes32(msg.data[abs + 32:abs + 64]);
        meta = bytes32(msg.data[abs + 64:abs + 96]);
    }

    /// @notice Consume an ACCOUNT_ASSET form block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded account, asset, and meta.
    function unpackAccountAssetValue(Cur memory cur) internal pure returns (AccountAsset memory value) {
        (value.account, value.asset, value.meta) = unpackAccountAsset(cur);
    }

    /// @notice Consume a RELOCATION block and return the host and amount.
    /// @param cur Cursor; advanced past the block.
    /// @return host Host node ID receiving the funding.
    /// @return amount Funding amount.
    function unpackRelocation(Cur memory cur) internal pure returns (uint host, uint amount) {
        (host, amount) = unpack2Uint(cur, Keys.Relocation);
    }

    /// @notice Consume a BOUNTY block and return the reward amount and relayer.
    /// @param cur Cursor; advanced past the block.
    /// @return amount Relayer reward amount.
    /// @return relayer Relayer account identifier.
    function unpackBounty(Cur memory cur) internal pure returns (uint amount, bytes32 relayer) {
        (bytes32 x, bytes32 y) = unpack64(cur, Keys.Bounty, 32);
        amount = uint(x);
        relayer = y;
    }

    /// @notice Consume a BOUNDS block and return the signed min and max values.
    /// @param cur Cursor; advanced past the block.
    /// @return min Lower signed bound.
    /// @return max Upper signed bound.
    function unpackBounds(Cur memory cur) internal pure returns (int min, int max) {
        uint abs = consume(cur, Keys.Bounds, 64, 64);
        assembly ("memory-safe") {
            min := calldataload(abs)
            max := calldataload(add(abs, 0x20))
        }
    }

    /// @notice Consume an AMOUNT block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Token amount.
    function unpackAmount(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackAssetAmount(cur, Keys.Amount);
    }

    /// @notice Consume an AMOUNT block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded asset, meta, and amount.
    function unpackAmountValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        (value.asset, value.meta, value.amount) = unpackAssetAmount(cur, Keys.Amount);
    }

    /// @notice Consume a BALANCE block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Token amount.
    function unpackBalance(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackAssetAmount(cur, Keys.Balance);
    }

    /// @notice Consume a BALANCE block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded asset, meta, and amount.
    function unpackBalanceValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        (value.asset, value.meta, value.amount) = unpackAssetAmount(cur, Keys.Balance);
    }

    /// @notice Consume a MINIMUM block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Minimum acceptable amount.
    function unpackMinimum(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackAssetAmount(cur, Keys.Minimum);
    }

    /// @notice Consume a MINIMUM block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded asset, meta, and minimum amount.
    function unpackMinimumValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        (value.asset, value.meta, value.amount) = unpackAssetAmount(cur, Keys.Minimum);
    }

    /// @notice Consume a MAXIMUM block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Maximum allowable spend.
    function unpackMaximum(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        return unpackAssetAmount(cur, Keys.Maximum);
    }

    /// @notice Consume a MAXIMUM block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded asset, meta, and maximum amount.
    function unpackMaximumValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        (value.asset, value.meta, value.amount) = unpackAssetAmount(cur, Keys.Maximum);
    }

    /// @notice Consume a HOST_ACCOUNT_ASSET form block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return host Host node ID.
    /// @return account Account identifier.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    function unpackHostAccountAsset(
        Cur memory cur
    ) internal pure returns (uint host, bytes32 account, bytes32 asset, bytes32 meta) {
        return unpackHostAccountAsset(cur, Keys.HostAccountAsset);
    }

    /// @notice Consume a HOST_ACCOUNT_ASSET form block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded host, account, asset, and meta.
    function unpackHostAccountAssetValue(Cur memory cur) internal pure returns (HostAccountAsset memory value) {
        (value.host, value.account, value.asset, value.meta) = unpackHostAccountAsset(cur, Keys.HostAccountAsset);
    }

    /// @notice Consume a PAYOUT block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return account Account identifier.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Token amount.
    function unpackPayout(
        Cur memory cur
    ) internal pure returns (bytes32 account, bytes32 asset, bytes32 meta, uint amount) {
        return unpackAccountAmount(cur, Keys.Payout);
    }

    /// @notice Consume a PAYOUT block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded account, asset, meta, and amount.
    function unpackPayoutValue(Cur memory cur) internal pure returns (AccountAmount memory value) {
        (value.account, value.asset, value.meta, value.amount) = unpackAccountAmount(cur, Keys.Payout);
    }

    /// @notice Consume an ACCOUNT_AMOUNT form block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return account Account identifier.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Token amount.
    function unpackAccountAmount(
        Cur memory cur
    ) internal pure returns (bytes32 account, bytes32 asset, bytes32 meta, uint amount) {
        return unpackAccountAmount(cur, Keys.AccountAmount);
    }

    /// @notice Consume an ACCOUNT_AMOUNT form block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded account, asset, meta, and amount.
    function unpackAccountAmountValue(Cur memory cur) internal pure returns (AccountAmount memory value) {
        (value.account, value.asset, value.meta, value.amount) = unpackAccountAmount(cur, Keys.AccountAmount);
    }

    /// @notice Consume an ALLOCATION block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return host Host node ID.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Token amount.
    function unpackAllocation(
        Cur memory cur
    ) internal pure returns (uint host, bytes32 asset, bytes32 meta, uint amount) {
        return unpackHostAmount(cur, Keys.Allocation);
    }

    /// @notice Consume an ALLOCATION block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded host, asset, meta, and amount.
    function unpackAllocationValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        (value.host, value.asset, value.meta, value.amount) = unpackHostAmount(cur, Keys.Allocation);
    }

    /// @notice Consume an ALLOWANCE block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return host Host node ID.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Token amount.
    function unpackAllowance(
        Cur memory cur
    ) internal pure returns (uint host, bytes32 asset, bytes32 meta, uint amount) {
        return unpackHostAmount(cur, Keys.Allowance);
    }

    /// @notice Consume an ALLOWANCE block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded host, asset, meta, and amount.
    function unpackAllowanceValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        (value.host, value.asset, value.meta, value.amount) = unpackHostAmount(cur, Keys.Allowance);
    }

    /// @notice Consume a CUSTODY block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return host Host node ID.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Token amount.
    function unpackCustody(
        Cur memory cur
    ) internal pure returns (uint host, bytes32 asset, bytes32 meta, uint amount) {
        return unpackHostAmount(cur, Keys.Custody);
    }

    /// @notice Consume a CUSTODY block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded host, asset, meta, and amount.
    function unpackCustodyValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        (value.host, value.asset, value.meta, value.amount) = unpackHostAmount(cur, Keys.Custody);
    }

    /// @notice Consume a TRANSACTION block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return from Source account identifier.
    /// @return to Destination account identifier.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Token amount.
    function unpackTransaction(
        Cur memory cur
    ) internal pure returns (bytes32 from, bytes32 to, bytes32 asset, bytes32 meta, uint amount) {
        return unpackTransaction(cur, Keys.Transaction);
    }

    /// @notice Consume a TRANSACTION block and return all fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded from, to, asset, meta, and amount.
    function unpackTxValue(Cur memory cur) internal pure returns (Tx memory value) {
        (value.from, value.to, value.asset, value.meta, value.amount) = unpackTransaction(cur);
    }

    // Type-specific dynamic decoders

    /// @notice Consume a STEP block and return its sub-command invocation fields.
    /// The `req` slice covers any additional payload bytes after the fixed head.
    /// @param cur Cursor; advanced past the block.
    /// @return target Destination node ID for the sub-command.
    /// @return value Native value to forward with the call.
    /// @return req Embedded request bytes for the sub-command.
    function unpackStep(Cur memory cur) internal pure returns (uint target, uint value, bytes calldata req) {
        (bytes32 a, bytes32 b, bytes calldata tail) = unpackHead64(cur, Keys.Step);
        return (uint(a), uint(b), tail);
    }

    /// @notice Consume a CALL block and return its target invocation fields.
    /// The `data` slice covers any additional payload bytes after the fixed head.
    /// @param cur Cursor; advanced past the block.
    /// @return target Target node ID to call.
    /// @return value Native value to forward with the call.
    /// @return data Raw calldata payload for the target.
    function unpackCall(Cur memory cur) internal pure returns (uint target, uint value, bytes calldata data) {
        (bytes32 a, bytes32 b, bytes calldata tail) = unpackHead64(cur, Keys.Call);
        return (uint(a), uint(b), tail);
    }

    // Type-specific validators

    /// @notice Validate an AUTH block at position `i` and extract deadline and proof.
    /// Does not advance the cursor.
    /// @param cur Source cursor.
    /// @param i Byte offset of the AUTH block.
    /// @param cid Command ID that the AUTH block must reference.
    /// @return deadline Expiry timestamp.
    /// @return proof Raw proof bytes (layout: `[bytes20 signer][bytes65 sig]`).
    function expectAuth(Cur memory cur, uint i, uint cid) internal pure returns (uint deadline, bytes calldata proof) {
        (uint abs, uint next) = expect(cur, i, Keys.Auth, 149, 0);
        if (uint(bytes32(msg.data[abs:abs + 32])) != cid) revert UnexpectedValue();
        deadline = uint(bytes32(msg.data[abs + 32:abs + 64]));
        proof = msg.data[abs + 64:cur.offset + next];
    }

    // -------------------------------------------------------------------------
    // require* - validate + advance (like consume with content checks)
    // -------------------------------------------------------------------------

    /// @notice Consume an asset block and assert it matches the expected asset.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block type key.
    /// @param asset Expected asset identifier.
    /// @return meta Metadata slot from the block.
    /// @return amount Amount from the block.
    function requireAssetAmount(
        Cur memory cur,
        bytes4 key,
        bytes32 asset
    ) internal pure returns (bytes32 meta, uint amount) {
        uint abs = consume(cur, key, 96, 96);
        if (bytes32(msg.data[abs:abs + 32]) != asset) revert UnexpectedValue();
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume an asset amount block and assert it matches the expected asset and meta.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block type key.
    /// @param asset Expected asset identifier.
    /// @param meta Expected metadata slot.
    /// @return amount Amount from the block.
    function requireAssetAmount(
        Cur memory cur,
        bytes4 key,
        bytes32 asset,
        bytes32 meta
    ) internal pure returns (uint amount) {
        uint abs = consume(cur, key, 96, 96);
        if (bytes32(msg.data[abs:abs + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[abs + 32:abs + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume an asset amount block, assert it matches the expected asset, and require the amount to be 1.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block type key.
    /// @param asset Expected asset identifier.
    /// @return meta Metadata slot from the block.
    function requireUnitAssetAmount(Cur memory cur, bytes4 key, bytes32 asset) internal pure returns (bytes32 meta) {
        uint abs = consume(cur, key, 96, 96);
        if (bytes32(msg.data[abs:abs + 32]) != asset) revert UnexpectedValue();
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        if (uint(bytes32(msg.data[abs + 64:abs + 96])) != 1) revert UnexpectedValue();
    }

    /// @notice Consume a MINIMUM block and assert it matches the expected asset and meta.
    /// @param cur Cursor; advanced past the block.
    /// @param asset Expected asset identifier.
    /// @param meta Expected metadata slot.
    /// @return amount Minimum amount from the block.
    function requireMinimum(Cur memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        return requireAssetAmount(cur, Keys.Minimum, asset, meta);
    }

    /// @notice Consume a host amount block and assert it matches the expected host.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block type key.
    /// @param host Expected host node ID.
    /// @return asset Asset identifier from the block.
    /// @return meta Metadata slot from the block.
    /// @return amount Amount from the block.
    function requireHostAmount(
        Cur memory cur,
        bytes4 key,
        uint host
    ) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, key, 128, 128);
        if (uint(bytes32(msg.data[abs:abs + 32])) != host) revert UnexpectedValue();
        asset = bytes32(msg.data[abs + 32:abs + 64]);
        meta = bytes32(msg.data[abs + 64:abs + 96]);
        amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    /// @notice Consume a host amount block and assert it matches the expected host and asset.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block type key.
    /// @param host Expected host node ID.
    /// @param asset Expected asset identifier.
    /// @return meta Metadata slot from the block.
    /// @return amount Amount from the block.
    function requireHostAmount(
        Cur memory cur,
        bytes4 key,
        uint host,
        bytes32 asset
    ) internal pure returns (bytes32 meta, uint amount) {
        uint abs = consume(cur, key, 128, 128);
        if (uint(bytes32(msg.data[abs:abs + 32])) != host) revert UnexpectedValue();
        if (bytes32(msg.data[abs + 32:abs + 64]) != asset) revert UnexpectedValue();
        meta = bytes32(msg.data[abs + 64:abs + 96]);
        amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    /// @notice Consume a host amount block, assert it matches the expected host and asset, and require the amount to be 1.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block type key.
    /// @param host Expected host node ID.
    /// @param asset Expected asset identifier.
    /// @return meta Metadata slot from the block.
    function requireUnitHostAmount(
        Cur memory cur,
        bytes4 key,
        uint host,
        bytes32 asset
    ) internal pure returns (bytes32 meta) {
        uint abs = consume(cur, key, 128, 128);
        if (uint(bytes32(msg.data[abs:abs + 32])) != host) revert UnexpectedValue();
        if (bytes32(msg.data[abs + 32:abs + 64]) != asset) revert UnexpectedValue();
        meta = bytes32(msg.data[abs + 64:abs + 96]);
        if (uint(bytes32(msg.data[abs + 96:abs + 128])) != 1) revert UnexpectedValue();
    }

    /// @notice Consume a host account asset block and assert it matches the expected host and account.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block key.
    /// @param host Expected host node ID.
    /// @param account Expected account identifier.
    /// @return asset Asset identifier from the block.
    /// @return meta Metadata slot from the block.
    function requireHostAccountAsset(
        Cur memory cur,
        bytes4 key,
        uint host,
        bytes32 account
    ) internal pure returns (bytes32 asset, bytes32 meta) {
        uint abs = consume(cur, key, 128, 128);
        if (uint(bytes32(msg.data[abs:abs + 32])) != host) revert UnexpectedValue();
        if (bytes32(msg.data[abs + 32:abs + 64]) != account) revert UnexpectedValue();
        asset = bytes32(msg.data[abs + 64:abs + 96]);
        meta = bytes32(msg.data[abs + 96:abs + 128]);
    }

    /// @notice Consume a host account asset block, assert it targets the expected host, and return account, asset, and meta.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected block key.
    /// @param host Expected host node ID.
    /// @return account Account identifier from the block.
    /// @return asset Asset identifier from the block.
    /// @return meta Metadata slot from the block.
    function requireHostAccountAsset(
        Cur memory cur,
        bytes4 key,
        uint host
    ) internal pure returns (bytes32 account, bytes32 asset, bytes32 meta) {
        uint abs = consume(cur, key, 128, 128);
        if (uint(bytes32(msg.data[abs:abs + 32])) != host) revert UnexpectedValue();
        account = bytes32(msg.data[abs + 32:abs + 64]);
        asset = bytes32(msg.data[abs + 64:abs + 96]);
        meta = bytes32(msg.data[abs + 96:abs + 128]);
    }

    /// @notice Consume a HOST_ACCOUNT_ASSET form block, assert it targets the expected host, and return account, asset, and meta.
    /// @param cur Cursor; advanced past the block.
    /// @param host Expected host node ID.
    /// @return account Account identifier from the block.
    /// @return asset Asset identifier from the block.
    /// @return meta Metadata slot from the block.
    function requireHostAccountAsset(
        Cur memory cur,
        uint host
    ) internal pure returns (bytes32 account, bytes32 asset, bytes32 meta) {
        return requireHostAccountAsset(cur, Keys.HostAccountAsset, host);
    }

    /// @notice Consume an AUTH block at the current position and verify the command ID.
    /// @param cur Cursor; advanced past the block.
    /// @param cid Expected command ID.
    /// @return deadline Expiry timestamp.
    /// @return proof Raw proof bytes.
    function requireAuth(Cur memory cur, uint cid) internal pure returns (uint deadline, bytes calldata proof) {
        (deadline, proof) = expectAuth(cur, cur.i, cid);
        cur.i += Sizes.Header + 64 + proof.length;
    }

    // -------------------------------------------------------------------------
    // Trailing-block helpers (search after bound)
    // -------------------------------------------------------------------------

    /// @notice Look for a NODE block anywhere in a calldata source and return its value.
    /// Scans from the start of `source` to the end.
    /// @param source Calldata block stream to search.
    /// @param backup Value to return if no NODE block is found.
    /// @return node Node ID from the NODE block, or `backup` if absent.
    function resolveNode(bytes calldata source, uint backup) internal pure returns (uint node) {
        Cur memory cur = open(source);
        uint i = find(cur, 0, Keys.Node);
        if (i == cur.len) return backup;

        (uint abs, ) = expect(cur, i, Keys.Node, 32, 32);
        return uint(bytes32(msg.data[abs:abs + 32]));
    }

    /// @notice Look for a NODE block anywhere in a calldata source and require a non-zero result.
    /// Scans from the start of `source` to the end.
    /// @param source Calldata block stream to search.
    /// @param backup Value to use if no NODE block is found.
    /// @return node Node ID from the NODE block, or `backup` if absent.
    function resolveNodeOrRevert(bytes calldata source, uint backup) internal pure returns (uint node) {
        node = resolveNode(source, backup);
        if (node == 0) revert ZeroNode();
    }

    /// @notice Look for an ACCOUNT block anywhere in a calldata source and return its value.
    /// Scans from the start of `source` to the end.
    /// @param source Calldata block stream to search.
    /// @param backup Account to return if no ACCOUNT block is found.
    /// @return account Account from the ACCOUNT block, or `backup` if absent.
    function resolveAccount(bytes calldata source, bytes32 backup) internal pure returns (bytes32 account) {
        Cur memory cur = open(source);
        uint i = find(cur, 0, Keys.Account);
        if (i == cur.len) return backup;

        (uint abs, ) = expect(cur, i, Keys.Account, 32, 32);
        return bytes32(msg.data[abs:abs + 32]);
    }

    /// @notice Look for a NODE block after the current run boundary and return its value.
    /// Searches from `cur.bound` to the end of the source region.
    /// @param cur Source cursor; `bound` marks the end of the primary run.
    /// @param backup Value to return if no NODE block is found.
    /// @return node Node ID from the NODE block, or `backup` if absent.
    function nodeAfter(Cur memory cur, uint backup) internal pure returns (uint node) {
        uint i = find(cur, cur.bound, Keys.Node);
        if (i == cur.len) return backup;

        (uint abs, ) = expect(cur, i, Keys.Node, 32, 32);
        return uint(bytes32(msg.data[abs:abs + 32]));
    }

    /// @notice Look for an ACCOUNT block after the current run boundary and return its value.
    /// Searches from `cur.bound` to the end of the source region.
    /// @param cur Source cursor; `bound` marks the end of the primary run.
    /// @param backup Account to return if no ACCOUNT block is found.
    /// @return account Account from the ACCOUNT block, or `backup` if absent.
    function accountAfter(Cur memory cur, bytes32 backup) internal pure returns (bytes32 account) {
        uint i = find(cur, cur.bound, Keys.Account);
        if (i == cur.len) return backup;

        (uint abs, ) = expect(cur, i, Keys.Account, 32, 32);
        return bytes32(msg.data[abs:abs + 32]);
    }

    /// @notice Parse the trailing AUTH block and compute the signed message hash.
    /// The AUTH block must occupy the final `Sizes.Auth` bytes of the source region
    /// and must begin after `cur.bound`.
    /// The signed slice covers from `cur.i` up to (but not including) the AUTH proof bytes.
    /// @param cur Source cursor; `bound` marks the end of the primary data region.
    /// @param cid Command ID that the signature must be bound to.
    /// @return hash keccak256 of the signed message slice.
    /// @return deadline Expiry timestamp from the AUTH block.
    /// @return proof Raw proof bytes (layout: `[bytes20 signer][bytes65 sig]`).
    function authLast(
        Cur memory cur,
        uint cid
    ) internal pure returns (bytes32 hash, uint deadline, bytes calldata proof) {
        if (cur.len - cur.i < Sizes.Auth) revert MalformedBlocks();

        uint i = cur.len - Sizes.Auth;
        if (i < cur.bound) revert MalformedBlocks();

        (deadline, proof) = expectAuth(cur, i, cid);
        hash = keccak256(msg.data[cur.offset + cur.i:cur.offset + cur.len - Sizes.Proof]);
    }
}
