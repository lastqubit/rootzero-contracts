// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AssetAmount, AccountAsset, AccountAmount, HostAmount, HostAccountAsset, Tx} from "../core/Types.sol";
import {Sizes} from "./Schema.sol";
import {Keys} from "./Keys.sol";

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
    /// @dev Prime block counts are not divisible by, or do not match, their declared group sizes.
    error BadRatio();

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

    /// @notice Create a cursor and prime it for a grouped iteration pass.
    /// Equivalent to `open(source)` followed by `primeRun(group)`.
    /// @param source Calldata slice that forms the block stream.
    /// @param group Expected block group size (e.g. 1 for single, 2 for paired).
    /// @return cur Cursor with `bound` set to the end of the first run.
    /// @return groups Number of block groups in the run (`prime block count / group`).
    function init(bytes calldata source, uint group) internal pure returns (Cur memory cur, uint groups) {
        cur = open(source);
        (, groups) = cur.primeRun(group);
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

    /// @notice Advance the cursor by `n` bytes within the source region.
    /// Reverts with `IncompleteCursor` if `n` exceeds the remaining cursor region length.
    /// @param cur Cursor to advance.
    /// @param n Number of bytes to skip from the current read position.
    function skip(Cur memory cur, uint n) internal pure returns (Cur memory) {
        if (n > cur.len - cur.i) revert IncompleteCursor();
        cur.i += n;
        return cur;
    }

    /// @notice Advance the cursor to a later absolute position within the source region.
    /// Reverts with `IncompleteCursor` if `i` exceeds the cursor region length or is before `cur.i`.
    /// @param cur Cursor to advance.
    /// @param i New read position (byte offset relative to source start).
    function skipTo(Cur memory cur, uint i) internal pure returns (Cur memory) {
        if (i > cur.len || cur.i > i) revert IncompleteCursor();
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

    /// @notice Return the full cursor region as a calldata slice.
    /// Does not advance the cursor; `cur.i` and `cur.bound` are ignored.
    /// @param cur Cursor whose backing region should be returned.
    /// @return data Calldata view over `[cur.offset, cur.offset + cur.len)`.
    function raw(Cur memory cur) internal pure returns (bytes calldata data) {
        if (cur.len > msg.data.length || cur.offset > msg.data.length - cur.len) revert MalformedBlocks();
        data = msg.data[cur.offset:cur.offset + cur.len];
    }

    /// @notice Return a sub-range of the cursor region as a calldata slice.
    /// Does not advance the cursor; `cur.i` and `cur.bound` are ignored.
    /// @param cur Source cursor.
    /// @param from Start byte offset within the source region (inclusive).
    /// @param to End byte offset within the source region (exclusive).
    /// @return data Calldata view over the requested sub-range.
    function raw(Cur memory cur, uint from, uint to) internal pure returns (bytes calldata data) {
        if (from > to || to > cur.len) revert MalformedBlocks();
        if (cur.len > msg.data.length || cur.offset > msg.data.length - cur.len) revert MalformedBlocks();
        data = msg.data[cur.offset + from:cur.offset + to];
    }

    /// @notice Hash a sub-range of the cursor region.
    /// Does not advance the cursor; `from` and `to` are relative to the source region.
    /// @param cur Source cursor.
    /// @param from Start byte offset within the source region (inclusive).
    /// @param to End byte offset within the source region (exclusive).
    /// @return digest Keccak256 hash of the requested sub-range.
    function hash(Cur memory cur, uint from, uint to) internal pure returns (bytes32 digest) {
        digest = keccak256(cur.raw(from, to));
    }

    /// @notice Read a block header at position `i` without advancing the cursor.
    /// @param cur Source cursor.
    /// @param i Byte offset of the block header within the source region.
    /// @return key Four-byte block type identifier.
    /// @return len Payload byte length declared in the header.
    function peek(Cur memory cur, uint i) internal pure returns (bytes4 key, uint len) {
        if (i + Sizes.Header > cur.len) revert MalformedBlocks();
        uint abs = cur.offset + i;
        key = bytes4(msg.data[abs:abs + 4]);
        len = uint32(bytes4(msg.data[abs + 4:abs + 8]));
        if (i + Sizes.Header + len > cur.len) revert MalformedBlocks();
    }

    /// @notice Return the byte offset immediately past the block at the current cursor position.
    /// Does not advance the cursor.
    /// @param cur Source cursor.
    /// @return Byte offset immediately past the current block, relative to the source region.
    function past(Cur memory cur) internal pure returns (uint) {
        (, uint len) = peek(cur, cur.i);
        return cur.i + Sizes.Header + len;
    }

    /// @notice Return true if position `i` is at a block header with the given key.
    /// Returns false when `i` is out of bounds or the key differs.
    /// @param cur Source cursor.
    /// @param i Byte offset of the block header within the source region.
    /// @param key Expected block type identifier.
    /// @return Whether the block header at `i` uses `key`.
    function hasAt(Cur memory cur, uint i, bytes4 key) internal pure returns (bool) {
        if (i > cur.len || Sizes.Header > cur.len - i) return false;
        uint abs = cur.offset + i;
        return bytes4(msg.data[abs:abs + 4]) == key;
    }

    /// @notice Return true if the current cursor position is at a block header with the given key.
    /// Returns false when `cur.i` is out of bounds or the key differs.
    /// @param cur Source cursor.
    /// @param key Expected block type identifier.
    /// @return Whether the block header at `cur.i` uses `key`.
    function isAt(Cur memory cur, bytes4 key) internal pure returns (bool) {
        return cur.hasAt(cur.i, key);
    }

    /// @notice Enter a block at the current position and return its next offset.
    /// Advances `cur.i` past the block header so the payload can be parsed
    /// directly from the same cursor. The returned `next` is the byte offset
    /// immediately after the block payload, relative to the current cursor region.
    /// @param cur Cursor positioned at the expected block; advanced past the 8-byte header.
    /// @param key Expected block key.
    /// @param min Minimum acceptable payload length.
    /// @param max Maximum acceptable payload length; 0 means unbounded.
    /// @return next Byte offset immediately after the block payload.
    function enter(Cur memory cur, bytes4 key, uint min, uint max) internal pure returns (uint next) {
        (bytes4 current, uint len) = peek(cur, cur.i);
        if (current != key) revert InvalidBlock();
        if (len < min || (max != 0 && len > max)) revert InvalidBlock();
        next = cur.i + Sizes.Header + len;
        cur.i += Sizes.Header;
    }

    /// @notice Validate a block at position `i` and return its payload location.
    /// Does not advance the cursor.
    /// @param cur Source cursor.
    /// @param i Byte offset of the block within the source region.
    /// @param end Required next offset after the block; 0 means no exact-end check.
    /// @param key Expected block type key; reverts if actual key differs.
    /// @param min Minimum acceptable payload length (inclusive).
    /// @param max Maximum acceptable payload length (inclusive); 0 means unbounded.
    /// @return abs Absolute calldata offset of the payload start.
    /// @return next Byte offset of the block immediately following this one (relative to source start).
    function expect(
        Cur memory cur,
        uint i,
        uint end,
        bytes4 key,
        uint min,
        uint max
    ) internal pure returns (uint abs, uint next) {
        (bytes4 current, uint len) = peek(cur, i);
        if (current != key) revert InvalidBlock();
        if (len < min || (max != 0 && len > max)) revert InvalidBlock();
        abs = cur.offset + i + Sizes.Header;
        next = i + Sizes.Header + len;
        if (end != 0 && next != end) revert IncompleteCursor();
    }

    /// @notice Validate and consume the current block, advancing `cur.i` past it.
    /// @param cur Cursor to advance.
    /// @param end Required next offset after the block; 0 means no exact-end check.
    /// @param key Expected block type key.
    /// @param min Minimum payload length.
    /// @param max Maximum payload length (0 = unbounded).
    /// @return abs Absolute calldata offset of the payload start.
    function consume(Cur memory cur, uint end, bytes4 key, uint min, uint max) internal pure returns (uint abs) {
        uint next;
        (abs, next) = expect(cur, cur.i, end, key, min, max);
        cur.i = next;
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
            next += Sizes.Header + len;

            unchecked {
                ++total;
            }
        }
    }

    /// @notice Initialise the cursor for a grouped iteration pass.
    /// Reads the key of the first block, counts the consecutive run of that key,
    /// stores the run end in `cur.bound`, validates that the count is a
    /// multiple of `group`, and returns the run key and normalized group count.
    /// @param cur Cursor to prime; `cur.bound` is updated in place.
    /// @param group Expected group size (e.g. 1 for single-asset, 2 for paired input/output).
    /// @return key Block type identifier of the run.
    /// @return groups Number of groups represented by the run (`block count / group`).
    function primeRun(Cur memory cur, uint group) internal pure returns (bytes4 key, uint groups) {
        if (group == 0) revert ZeroGroup();
        key = cur.i + 4 > cur.len ? bytes4(0) : bytes4(msg.data[cur.offset + cur.i:cur.offset + cur.i + 4]);
        uint count;
        (count, cur.bound) = countRun(cur, cur.i, key);
        if (count == 0) revert ZeroCursor();
        if (count % group != 0) revert BadRatio();
        groups = count / group;
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
            i += Sizes.Header + len;
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

    /// @notice Enter a List block at the current position and return the next offset.
    /// Advances `cur.i` past the list header so the list members can be parsed
    /// directly from the same cursor. The returned `next` is the byte offset
    /// immediately after the list payload, relative to the current cursor region.
    /// @param cur Cursor positioned at a list block; advanced past the 8-byte header.
    /// @return next Byte offset immediately after the list payload.
    function list(Cur memory cur) internal pure returns (uint next) {
        next = enter(cur, Keys.List, 0, 0);
    }

    /// @notice Consume a block with the given key at the current position and return a cursor over the full block slice.
    /// Advances `cur.i` past the block while the returned cursor is scoped to the
    /// full block bytes as a fresh zero-based region.
    /// @param cur Cursor positioned at the expected block.
    /// @param key Expected block type key.
    /// @return out Cursor scoped to the full block.
    function take(Cur memory cur, bytes4 key) internal pure returns (Cur memory out) {
        (, uint next) = expect(cur, cur.i, 0, key, 0, 0);
        out = cur.slice(cur.i, next);
        cur.i = next;
    }

    /// @notice Return whether the remaining cursor region is empty or exactly one block with `key`.
    /// Returns false for an empty remaining region. Reverts if the next block has another key or
    /// if a matching block is followed by trailing bytes.
    /// @param cur Source cursor.
    /// @param key Expected optional block key.
    /// @return Whether the remaining region contains exactly one block with `key`.
    function maybeOnly(Cur memory cur, bytes4 key) internal pure returns (bool) {
        if (cur.i == cur.len) return false;
        if (!cur.isAt(key)) revert InvalidBlock();
        if (cur.past() != cur.len) revert IncompleteCursor();
        return true;
    }

    /// @notice Consume an optional block with the given key and return a cursor over the full block slice.
    /// If the current block key does not match, returns an empty cursor and leaves `cur.i` unchanged.
    /// Otherwise behaves like `take(cur, key)`.
    /// @param cur Cursor positioned at an optional block.
    /// @param key Optional block type key.
    /// @return out Cursor scoped to the full matching block, or empty when no matching block is present.
    function maybeTake(Cur memory cur, bytes4 key) internal pure returns (Cur memory out) {
        return cur.isAt(key) ? take(cur, key) : cur.slice(cur.i, cur.i);
    }

    /// @notice Consume an optional DATA block at the current position and return a cursor over the full block slice.
    /// If the current block is not DATA, returns an empty cursor and leaves `cur.i` unchanged.
    /// Otherwise behaves like `take(cur, Keys.Data)`.
    /// @param cur Cursor positioned at an optional DATA block.
    /// @return out Cursor scoped to the full DATA block, or empty when no DATA block is present.
    function maybeData(Cur memory cur) internal pure returns (Cur memory out) {
        return maybeTake(cur, Keys.Data);
    }

    /// @notice Enter a List block, prime its member run, and return the group count.
    /// @param cur Cursor positioned at a list block; advanced past the 8-byte header.
    /// @param group Expected block group size for the list item stream.
    /// @return groups Number of block groups in the list payload.
    /// @return next Byte offset immediately after the list payload.
    function list(Cur memory cur, uint group) internal pure returns (uint groups, uint next) {
        next = list(cur);
        (, groups) = cur.primeRun(group);
        if (cur.bound != next) revert IncompleteCursor();
    }

    /// @notice Exit a nested region at an exact boundary.
    /// Reverts with `IncompleteCursor` if `end` exceeds the cursor region length
    /// or `cur.i != end`.
    /// @param cur Cursor to check.
    /// @param end Relative end offset of the nested region.
    function exit(Cur memory cur, uint end) internal pure {
        if (end > cur.len || cur.i != end) revert IncompleteCursor();
    }

    /// @notice Assert that the cursor has consumed exactly up to `bound`.
    /// Reverts with `IncompleteCursor` if `bound` is zero or `cur.i != cur.bound`.
    /// @param cur Cursor to check.
    function close(Cur memory cur) internal pure {
        if (cur.bound == 0 || cur.i != cur.bound) revert IncompleteCursor();
    }

    /// @notice Assert that the cursor has consumed its entire source region.
    /// Reverts with `IncompleteCursor` when `cur.i != cur.len`.
    /// @param cur Cursor to check.
    function complete(Cur memory cur) internal pure {
        if (cur.i != cur.len) revert IncompleteCursor();
    }

    // -------------------------------------------------------------------------
    // Block factory helpers
    // -------------------------------------------------------------------------

    /// @notice Encode a block with a raw payload.
    /// @param key Block type key.
    /// @param data Raw payload bytes.
    /// @return Encoded block bytes.
    function createBlock(bytes4 key, bytes memory data) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(data.length)), data);
    }

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

    /// @notice Encode a BYTES block with a raw payload.
    /// @param data Raw payload bytes.
    /// @return Encoded BYTES block bytes.
    function toBytesBlock(bytes memory data) internal pure returns (bytes memory) {
        return createBlock(Keys.Bytes, data);
    }

    /// @notice Encode a BOUNTY block.
    /// @param bounty Relayer reward amount.
    /// @param relayer Relayer account identifier.
    /// @return Encoded BOUNTY block bytes.
    function toBountyBlock(uint bounty, bytes32 relayer) internal pure returns (bytes memory) {
        return createBlock64(Keys.Bounty, bytes32(bounty), relayer);
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
    function toCustodyBlock(uint host, bytes32 asset, bytes32 meta, uint amount) internal pure returns (bytes memory) {
        return createBlock128(Keys.Custody, bytes32(host), asset, meta, bytes32(amount));
    }

    /// @notice Encode a STEP block.
    /// @param target Command target identifier.
    /// @param value Native value forwarded with the step.
    /// @param request Raw nested request payload.
    /// @return Encoded STEP block bytes.
    function toStepBlock(uint target, uint value, bytes memory request) internal pure returns (bytes memory) {
        return createBlock(Keys.Step, bytes.concat(bytes32(target), bytes32(value), toBytesBlock(request)));
    }

    /// @notice Encode a CALL block.
    /// @param target Target node identifier.
    /// @param value Native value forwarded with the call.
    /// @param data Raw calldata payload for the target.
    /// @return Encoded CALL block bytes.
    function toCallBlock(uint target, uint value, bytes memory data) internal pure returns (bytes memory) {
        return createBlock(Keys.Call, bytes.concat(bytes32(target), bytes32(value), toBytesBlock(data)));
    }

    /// @notice Encode a CONTEXT block.
    /// @param account Command account identifier.
    /// @param state Embedded state block stream.
    /// @param request Embedded request block stream.
    /// @return Encoded CONTEXT block bytes.
    function toContextBlock(bytes32 account, bytes memory state, bytes memory request) internal pure returns (bytes memory) {
        return createBlock(Keys.Context, bytes.concat(account, toBytesBlock(state), toBytesBlock(request)));
    }

    /// @notice Encode a RELAY block.
    /// @param target Command target identifier.
    /// @param value Native value assigned to the relay.
    /// @param account Command account identifier.
    /// @param state Embedded state block stream.
    /// @param request Embedded request block stream.
    /// @return Encoded RELAY block bytes.
    function toRelayBlock(
        uint target,
        uint value,
        bytes32 account,
        bytes memory state,
        bytes memory request
    ) internal pure returns (bytes memory) {
        return createBlock(Keys.Relay, bytes.concat(bytes32(target), bytes32(value), toContextBlock(account, state, request)));
    }

    // -------------------------------------------------------------------------
    // Raw calldata loaders
    // -------------------------------------------------------------------------

    /// @notice Read the next calldata word from the cursor and advance by `n` bytes.
    /// @dev Performs no bounds, key, length, or cursor checks. Always loads 32 bytes;
    ///      callers may cast the returned word to `bytesN` when `n < 32`.
    /// @param cur Cursor whose current position is advanced by `n` bytes.
    /// @param n Number of bytes to advance.
    /// @return value Loaded word.
    function read(Cur memory cur, uint n) internal pure returns (bytes32 value) {
        uint abs = cur.offset + cur.i;
        assembly ("memory-safe") {
            value := calldataload(abs)
        }
        cur.i += n;
    }

    /// @notice Read the next 16 bytes from the cursor and advance by 16 bytes.
    /// @dev Performs no bounds, key, length, or cursor checks.
    /// @param cur Cursor whose current position is advanced by 16 bytes.
    /// @return value Loaded bytes16 value.
    function read16(Cur memory cur) internal pure returns (bytes16 value) {
        uint abs = cur.offset + cur.i;
        assembly ("memory-safe") {
            value := calldataload(abs)
        }
        cur.i += 16;
    }

    /// @notice Read the next 32-byte word from the cursor and advance by one word.
    /// @dev Performs no bounds, key, length, or cursor checks.
    /// @param cur Cursor whose current position is advanced by 32 bytes.
    /// @return value Loaded word.
    function read32(Cur memory cur) internal pure returns (bytes32 value) {
        uint abs = cur.offset + cur.i;
        assembly ("memory-safe") {
            value := calldataload(abs)
        }
        cur.i += 32;
    }

    /// @notice Read the next two 32-byte words from the cursor and advance by 64 bytes.
    /// @dev Performs no bounds, key, length, or cursor checks.
    /// @param cur Cursor whose current position is advanced by 64 bytes.
    /// @return a First loaded word.
    /// @return b Second loaded word.
    function read64(Cur memory cur) internal pure returns (bytes32 a, bytes32 b) {
        uint abs = cur.offset + cur.i;
        assembly ("memory-safe") {
            a := calldataload(abs)
            b := calldataload(add(abs, 0x20))
        }
        cur.i += 64;
    }

    /// @notice Read the next three 32-byte words from the cursor and advance by 96 bytes.
    /// @dev Performs no bounds, key, length, or cursor checks.
    /// @param cur Cursor whose current position is advanced by 96 bytes.
    /// @return a First loaded word.
    /// @return b Second loaded word.
    /// @return c Third loaded word.
    function read96(Cur memory cur) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        uint abs = cur.offset + cur.i;
        assembly ("memory-safe") {
            a := calldataload(abs)
            b := calldataload(add(abs, 0x20))
            c := calldataload(add(abs, 0x40))
        }
        cur.i += 96;
    }

    /// @notice Consume the next 32-byte word and require it to match `expected`.
    /// @dev Performs no bounds, key, length, or cursor checks beyond the value comparison.
    /// @param cur Cursor whose current position is advanced by 32 bytes.
    /// @param expected Required word value.
    function require32(Cur memory cur, bytes32 expected) internal pure {
        if (read32(cur) != expected) revert UnexpectedValue();
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
        (uint abs, uint next) = expect(cur, cur.i, 0, key, 0, 0);
        data = msg.data[abs:cur.offset + next];
        cur.i = next;
    }

    /// @notice Consume a reserved BYTES block and return its raw payload.
    /// @param cur Cursor; advanced past the BYTES block.
    /// @return data Raw BYTES payload.
    function unpackBytes(Cur memory cur) internal pure returns (bytes calldata data) {
        return unpackRaw(cur, Keys.Bytes);
    }

    /// @notice Consume a dynamic block with a single bytes32 payload.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return value Decoded bytes32.
    function unpack32(Cur memory cur, bytes4 key) internal pure returns (bytes32 value) {
        uint abs = consume(cur, 0, key, 32, 32);
        value = bytes32(msg.data[abs:abs + 32]);
    }

    /// @notice Consume a dynamic block with two bytes32 payload words.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    function unpack64(Cur memory cur, bytes4 key) internal pure returns (bytes32 a, bytes32 b) {
        uint abs = consume(cur, 0, key, 64, 64);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
    }

    /// @notice Consume a dynamic block with three bytes32 payload words.
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    /// @return c Third decoded bytes32.
    function unpack96(Cur memory cur, bytes4 key) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        uint abs = consume(cur, 0, key, 96, 96);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
    }

    /// @notice Consume a dynamic block with a 128-byte payload (four 32-byte words).
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    /// @return c Third decoded bytes32.
    /// @return d Fourth decoded bytes32.
    function unpack128(Cur memory cur, bytes4 key) internal pure returns (bytes32 a, bytes32 b, bytes32 c, bytes32 d) {
        uint abs = consume(cur, 0, key, 128, 128);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
        d = bytes32(msg.data[abs + 96:abs + 128]);
    }

    /// @notice Consume a dynamic block with a 160-byte payload (five 32-byte words).
    /// @param cur Cursor; advanced past the block.
    /// @param key Expected dynamic block key.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    /// @return c Third decoded bytes32.
    /// @return d Fourth decoded bytes32.
    /// @return e Fifth decoded bytes32.
    function unpack160(
        Cur memory cur,
        bytes4 key
    ) internal pure returns (bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e) {
        uint abs = consume(cur, 0, key, 160, 160);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
        d = bytes32(msg.data[abs + 96:abs + 128]);
        e = bytes32(msg.data[abs + 128:abs + 160]);
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
        uint abs = consume(cur, 0, key, 96, 96);
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
        uint abs = consume(cur, 0, key, 128, 128);
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
        uint abs = consume(cur, 0, key, 128, 128);
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
        uint abs = consume(cur, 0, key, 128, 128);
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
        uint abs = consume(cur, 0, key, 160, 160);
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
        account = unpack32(cur, Keys.Account);
    }

    /// @notice Consume a NODE block and return the node ID.
    /// @param cur Cursor; advanced past the block.
    /// @return node Node identifier.
    function unpackNode(Cur memory cur) internal pure returns (uint node) {
        node = uint(unpack32(cur, Keys.Node));
    }

    /// @notice Consume a FEE block and return the amount.
    /// @param cur Cursor; advanced past the block.
    /// @return amount Fee amount.
    function unpackFee(Cur memory cur) internal pure returns (uint amount) {
        amount = uint(unpack32(cur, Keys.Fee));
    }

    /// @notice Consume an ASSET block and return the asset descriptor fields.
    /// @param cur Cursor; advanced past the block.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    function unpackAsset(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta) {
        (asset, meta) = unpack64(cur, Keys.Asset);
    }

    /// @notice Consume an ACCOUNT_ASSET form block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return account Account identifier.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    function unpackAccountAsset(Cur memory cur) internal pure returns (bytes32 account, bytes32 asset, bytes32 meta) {
        uint abs = consume(cur, 0, Keys.AccountAsset, 96, 96);
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

    /// @notice Consume a BOUNTY block and return the reward amount and relayer.
    /// @param cur Cursor; advanced past the block.
    /// @return amount Relayer reward amount.
    /// @return relayer Relayer account identifier.
    function unpackBounty(Cur memory cur) internal pure returns (uint amount, bytes32 relayer) {
        (bytes32 x, bytes32 y) = unpack64(cur, Keys.Bounty);
        amount = uint(x);
        relayer = y;
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
    function unpackCustody(Cur memory cur) internal pure returns (uint host, bytes32 asset, bytes32 meta, uint amount) {
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
    /// The `req` slice is the raw payload of the block's required BYTES child.
    /// @param cur Cursor; advanced past the block.
    /// @return target Destination node ID for the sub-command.
    /// @return value Native value to forward with the call.
    /// @return req Embedded request bytes for the sub-command.
    function unpackStep(Cur memory cur) internal pure returns (uint target, uint value, bytes calldata req) {
        uint end = cur.enter(Keys.Step, 64 + Sizes.Header, 0);
        target = uint(cur.read32());
        value = uint(cur.read32());
        req = cur.unpackBytes();
        cur.exit(end);
    }

    /// @notice Consume a CALL block and return its target invocation fields.
    /// The `data` slice is the raw payload of the block's required BYTES child.
    /// @param cur Cursor; advanced past the block.
    /// @return target Target node ID to call.
    /// @return value Native value to forward with the call.
    /// @return data Raw calldata payload for the target.
    function unpackCall(Cur memory cur) internal pure returns (uint target, uint value, bytes calldata data) {
        uint end = cur.enter(Keys.Call, 64 + Sizes.Header, 0);
        target = uint(cur.read32());
        value = uint(cur.read32());
        data = cur.unpackBytes();
        cur.exit(end);
    }

    /// @notice Consume a CONTEXT block and return its command context fields.
    /// The `state` and `request` slices are the raw payloads of the required BYTES children.
    /// @param cur Cursor; advanced past the block.
    /// @return account Command account identifier.
    /// @return state Embedded state block stream.
    /// @return request Embedded request block stream.
    function unpackContext(Cur memory cur) internal pure returns (bytes32 account, bytes calldata state, bytes calldata request) {
        uint end = cur.enter(Keys.Context, 32 + 2 * Sizes.Header, 0);
        account = cur.read32();
        state = cur.unpackBytes();
        request = cur.unpackBytes();
        cur.exit(end);
    }

    /// @notice Consume a RELAY block and return its target, value, and context fields.
    /// @param cur Cursor; advanced past the block.
    /// @return target Destination command/node ID.
    /// @return value Native value assigned to the relay.
    /// @return account Command account identifier.
    /// @return state Embedded state block stream.
    /// @return request Embedded request block stream.
    function unpackRelay(
        Cur memory cur
    ) internal pure returns (uint target, uint value, bytes32 account, bytes calldata state, bytes calldata request) {
        uint end = cur.enter(Keys.Relay, 64 + Sizes.Header + 32 + 2 * Sizes.Header, 0);
        target = uint(cur.read32());
        value = uint(cur.read32());
        (account, state, request) = cur.unpackContext();
        cur.exit(end);
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
        (uint abs, uint next) = expect(cur, i, 0, Keys.Auth, 64 + Sizes.Header + Sizes.Proof, 0);
        if (uint(bytes32(msg.data[abs:abs + 32])) != cid) revert UnexpectedValue();
        deadline = uint(bytes32(msg.data[abs + 32:abs + 64]));

        (abs, ) = expect(cur, i + Sizes.Header + 64, next, Keys.Bytes, Sizes.Proof, Sizes.Proof);
        proof = msg.data[abs:abs + Sizes.Proof];
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
        uint abs = consume(cur, 0, key, 96, 96);
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
        uint abs = consume(cur, 0, key, 96, 96);
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
        uint abs = consume(cur, 0, key, 96, 96);
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
        uint abs = consume(cur, 0, key, 128, 128);
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
        uint abs = consume(cur, 0, key, 128, 128);
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
        uint abs = consume(cur, 0, key, 128, 128);
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
        uint abs = consume(cur, 0, key, 128, 128);
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
        uint abs = consume(cur, 0, key, 128, 128);
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
        cur.i += Sizes.Auth;
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

        (uint abs, ) = expect(cur, i, 0, Keys.Node, 32, 32);
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

        (uint abs, ) = expect(cur, i, 0, Keys.Account, 32, 32);
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

        (uint abs, ) = expect(cur, i, 0, Keys.Node, 32, 32);
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

        (uint abs, ) = expect(cur, i, 0, Keys.Account, 32, 32);
        return bytes32(msg.data[abs:abs + 32]);
    }

    /// @notice Parse the trailing AUTH block and compute the signed message hash.
    /// The AUTH block must occupy the final `Sizes.Auth` bytes of the source region
    /// and must begin after `cur.bound`.
    /// The signed slice covers from `cur.i` up to (but not including) the AUTH proof bytes.
    /// @param cur Source cursor; `bound` marks the end of the primary data region.
    /// @param cid Command ID that the signature must be bound to.
    /// @return digest keccak256 of the signed message slice.
    /// @return deadline Expiry timestamp from the AUTH block.
    /// @return proof Raw proof bytes (layout: `[bytes20 signer][bytes65 sig]`).
    function authLast(
        Cur memory cur,
        uint cid
    ) internal pure returns (bytes32 digest, uint deadline, bytes calldata proof) {
        if (cur.len - cur.i < Sizes.Auth) revert MalformedBlocks();

        uint i = cur.len - Sizes.Auth;
        if (i < cur.bound) revert MalformedBlocks();

        (deadline, proof) = expectAuth(cur, i, cid);
        digest = cur.hash(cur.i, cur.len - Sizes.Proof);
    }
}
