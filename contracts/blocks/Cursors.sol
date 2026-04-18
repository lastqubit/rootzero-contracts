// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {HostAsset, AssetAmount, HostAmount, Tx, Keys, Sizes} from "./Schema.sol";
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
    /// @dev `primeRun` found zero blocks of the expected key; the cursor region is empty.
    error ZeroCursor();
    /// @dev `complete` called but the cursor has not consumed exactly up to `bound`.
    error IncompleteCursor();
    /// @dev `primeRun` was called with a zero group size.
    error ZeroGroup();
    /// @dev A recipient field was required but the block or fallback was zero.
    error ZeroRecipient();
    /// @dev A node field was required but the block or fallback was zero.
    error ZeroNode();
    /// @dev A field value did not match the expected value.
    error UnexpectedValue();
    /// @dev Input and output block counts are not proportional to their declared group sizes.
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

    /// @notice Enter a List block, prime its member run, and require an exact raw block count.
    /// @param cur Cursor positioned at a list block; advanced past the 8-byte header.
    /// @param group Expected block group size for the list item stream.
    /// @param requiredCount Required number of blocks in the list payload.
    /// @return next Byte offset immediately after the list payload.
    function list(Cur memory cur, uint group, uint requiredCount) internal pure returns (uint next) {
        uint count;
        (count, next) = list(cur, group);
        if (count != requiredCount) revert BadRatio();
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
    function create32(bytes4 key, bytes32 value) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x20)), value);
    }

    /// @notice Encode a block with a 32-byte fixed head followed by a variable-length tail.
    /// @param key Block type key.
    /// @param head Fixed 32-byte head payload.
    /// @param tail Variable-length payload bytes appended after the head.
    /// @return Encoded block bytes.
    function createHead32(bytes4 key, bytes32 head, bytes memory tail) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x20 + tail.length)), head, tail);
    }

    /// @notice Encode a block with two 32-byte payload words (64-byte payload).
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @return Encoded block bytes.
    function create64(bytes4 key, bytes32 a, bytes32 b) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x40)), a, b);
    }

    /// @notice Encode a block with a 64-byte fixed head followed by a variable-length tail.
    /// @param key Block type key.
    /// @param a First fixed payload word.
    /// @param b Second fixed payload word.
    /// @param tail Variable-length payload bytes appended after the fixed head.
    /// @return Encoded block bytes.
    function createHead64(bytes4 key, bytes32 a, bytes32 b, bytes memory tail) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x40 + tail.length)), a, b, tail);
    }

    /// @notice Encode a block with three 32-byte payload words (96-byte payload).
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @return Encoded block bytes.
    function create96(bytes4 key, bytes32 a, bytes32 b, bytes32 c) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x60)), a, b, c);
    }

    /// @notice Encode a block with four 32-byte payload words (128-byte payload).
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @return Encoded block bytes.
    function create128(bytes4 key, bytes32 a, bytes32 b, bytes32 c, bytes32 d) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x80)), a, b, c, d);
    }

    /// @notice Encode a BOUNTY block.
    /// @param bounty Relayer reward amount.
    /// @param relayer Relayer account identifier.
    /// @return Encoded BOUNTY block bytes.
    function toBountyBlock(uint bounty, bytes32 relayer) internal pure returns (bytes memory) {
        return create64(Keys.Bounty, bytes32(bounty), relayer);
    }

    /// @notice Encode a MINIMUMS block.
    /// @param a First minimum amount.
    /// @param b Second minimum amount.
    /// @return Encoded MINIMUMS block bytes.
    function toMinimumsBlock(uint a, uint b) internal pure returns (bytes memory) {
        return create64(Keys.Minimums, bytes32(a), bytes32(b));
    }

    /// @notice Encode a MAXIMUMS block.
    /// @param a First maximum amount.
    /// @param b Second maximum amount.
    /// @return Encoded MAXIMUMS block bytes.
    function toMaximumsBlock(uint a, uint b) internal pure returns (bytes memory) {
        return create64(Keys.Maximums, bytes32(a), bytes32(b));
    }

    /// @notice Encode a FEE block.
    /// @param amount Fee amount.
    /// @return Encoded FEE block bytes.
    function toFeeBlock(uint amount) internal pure returns (bytes memory) {
        return create32(Keys.Fee, bytes32(amount));
    }

    /// @notice Encode a STEP block.
    /// @param target Command target identifier.
    /// @param value Native value forwarded with the step.
    /// @param request Variable-length nested request payload.
    /// @return Encoded STEP block bytes.
    function toStepBlock(uint target, uint value, bytes memory request) internal pure returns (bytes memory) {
        return createHead64(Keys.Step, bytes32(target), bytes32(value), request);
    }

    /// @notice Encode a BALANCE block.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    /// @return Encoded BALANCE block bytes.
    function toBalanceBlock(bytes32 asset, bytes32 meta, uint amount) internal pure returns (bytes memory) {
        return create96(Keys.Balance, asset, meta, bytes32(amount));
    }

    /// @notice Encode a CUSTODY block.
    /// @param host Host node ID holding the custody.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    /// @return Encoded CUSTODY block bytes.
    function toCustodyBlock(uint host, bytes32 asset, bytes32 meta, uint amount) internal pure returns (bytes memory) {
        return create128(Keys.Custody, bytes32(host), asset, meta, bytes32(amount));
    }

    // -------------------------------------------------------------------------
    // Trailing-block helpers (search after bound)
    // -------------------------------------------------------------------------

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

    /// @notice Look for a RECIPIENT block after the current run boundary and return its value.
    /// Searches from `cur.bound` to the end of the source region.
    /// @param cur Source cursor; `bound` marks the end of the primary run.
    /// @param backup Account to return if no RECIPIENT block is found.
    /// @return account Recipient account from the RECIPIENT block, or `backup` if absent.
    function recipientAfter(Cur memory cur, bytes32 backup) internal pure returns (bytes32 account) {
        uint i = find(cur, cur.bound, Keys.Recipient);
        if (i == cur.len) return backup;

        (uint abs, ) = expect(cur, i, Keys.Recipient, 32, 32);
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

    // -------------------------------------------------------------------------
    // unpack* — consume current block and decode payload fields
    // -------------------------------------------------------------------------

    /// @notice Consume a BALANCE block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded asset, meta, and amount.
    function unpackBalanceValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        uint abs = consume(cur, Keys.Balance, 96, 96);
        value.asset = bytes32(msg.data[abs:abs + 32]);
        value.meta = bytes32(msg.data[abs + 32:abs + 64]);
        value.amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume an AMOUNT block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded asset, meta, and amount.
    function unpackAmountValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        uint abs = consume(cur, Keys.Amount, 96, 96);
        value.asset = bytes32(msg.data[abs:abs + 32]);
        value.meta = bytes32(msg.data[abs + 32:abs + 64]);
        value.amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume an AMOUNT block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Token amount.
    function unpackAmount(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, Keys.Amount, 96, 96);
        asset = bytes32(msg.data[abs:abs + 32]);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume a BALANCE block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Token amount.
    function unpackBalance(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, Keys.Balance, 96, 96);
        asset = bytes32(msg.data[abs:abs + 32]);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume a MINIMUM block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Minimum acceptable amount.
    function unpackMinimum(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, Keys.Minimum, 96, 96);
        asset = bytes32(msg.data[abs:abs + 32]);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume a MINIMUM block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded asset, meta, and minimum amount.
    function unpackMinimumValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        uint abs = consume(cur, Keys.Minimum, 96, 96);
        value.asset = bytes32(msg.data[abs:abs + 32]);
        value.meta = bytes32(msg.data[abs + 32:abs + 64]);
        value.amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume a MINIMUMS block and return the two minimum amounts.
    /// @param cur Cursor; advanced past the block.
    /// @return a First minimum amount.
    /// @return b Second minimum amount.
    function unpackMinimums(Cur memory cur) internal pure returns (uint a, uint b) {
        uint abs = consume(cur, Keys.Minimums, 64, 64);
        a = uint(bytes32(msg.data[abs:abs + 32]));
        b = uint(bytes32(msg.data[abs + 32:abs + 64]));
    }

    /// @notice Consume a MAXIMUMS block and return the two maximum amounts.
    /// @param cur Cursor; advanced past the block.
    /// @return a First maximum amount.
    /// @return b Second maximum amount.
    function unpackMaximums(Cur memory cur) internal pure returns (uint a, uint b) {
        uint abs = consume(cur, Keys.Maximums, 64, 64);
        a = uint(bytes32(msg.data[abs:abs + 32]));
        b = uint(bytes32(msg.data[abs + 32:abs + 64]));
    }

    /// @notice Consume a MAXIMUM block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Maximum allowable spend.
    function unpackMaximum(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, Keys.Maximum, 96, 96);
        asset = bytes32(msg.data[abs:abs + 32]);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume a MAXIMUM block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded asset, meta, and maximum amount.
    function unpackMaximumValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        uint abs = consume(cur, Keys.Maximum, 96, 96);
        value.asset = bytes32(msg.data[abs:abs + 32]);
        value.meta = bytes32(msg.data[abs + 32:abs + 64]);
        value.amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume a STEP block and return its sub-command invocation fields.
    /// The `req` slice covers any additional payload bytes after the fixed head.
    /// @param cur Cursor; advanced past the block.
    /// @return target Destination node ID for the sub-command.
    /// @return value Native value to forward with the call.
    /// @return req Embedded request bytes for the sub-command.
    function unpackStep(Cur memory cur) internal pure returns (uint target, uint value, bytes calldata req) {
        uint abs = consume(cur, Keys.Step, 64, 0);
        target = uint(bytes32(msg.data[abs:abs + 32]));
        value = uint(bytes32(msg.data[abs + 32:abs + 64]));
        req = msg.data[abs + 64:cur.offset + cur.i];
    }

    /// @notice Consume a RECIPIENT block and return the account.
    /// @param cur Cursor; advanced past the block.
    /// @return account Destination account identifier.
    function unpackRecipient(Cur memory cur) internal pure returns (bytes32 account) {
        uint abs = consume(cur, Keys.Recipient, 32, 32);
        account = bytes32(msg.data[abs:abs + 32]);
    }

    /// @notice Consume a RATE block and return the value.
    /// @param cur Cursor; advanced past the block.
    /// @return value Encoded ratio or rate.
    function unpackRate(Cur memory cur) internal pure returns (uint value) {
        uint abs = consume(cur, Keys.Rate, 32, 32);
        value = uint(bytes32(msg.data[abs:abs + 32]));
    }

    /// @notice Consume a QUANTITY block and return the amount.
    /// @param cur Cursor; advanced past the block.
    /// @return amount Scalar quantity value.
    function unpackQuantity(Cur memory cur) internal pure returns (uint amount) {
        uint abs = consume(cur, Keys.Quantity, 32, 32);
        amount = uint(bytes32(msg.data[abs:abs + 32]));
    }

    /// @notice Consume a FEE block and return the amount.
    /// @param cur Cursor; advanced past the block.
    /// @return amount Fee amount.
    function unpackFee(Cur memory cur) internal pure returns (uint amount) {
        uint abs = consume(cur, Keys.Fee, 32, 32);
        amount = uint(bytes32(msg.data[abs:abs + 32]));
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

    /// @notice Consume an ASSET block and return the asset descriptor fields.
    /// @param cur Cursor; advanced past the block.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    function unpackAsset(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta) {
        uint abs = consume(cur, Keys.Asset, 64, 64);
        asset = bytes32(msg.data[abs:abs + 32]);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
    }

    /// @notice Consume a FUNDING block and return the host and amount.
    /// @param cur Cursor; advanced past the block.
    /// @return host Host node ID receiving the funding.
    /// @return amount Funding amount.
    function unpackFunding(Cur memory cur) internal pure returns (uint host, uint amount) {
        uint abs = consume(cur, Keys.Funding, 64, 64);
        host = uint(bytes32(msg.data[abs:abs + 32]));
        amount = uint(bytes32(msg.data[abs + 32:abs + 64]));
    }

    /// @notice Consume a BOUNTY block and return the reward amount and relayer.
    /// @param cur Cursor; advanced past the block.
    /// @return amount Relayer reward amount.
    /// @return relayer Relayer account identifier.
    function unpackBounty(Cur memory cur) internal pure returns (uint amount, bytes32 relayer) {
        uint abs = consume(cur, Keys.Bounty, 64, 64);
        amount = uint(bytes32(msg.data[abs:abs + 32]));
        relayer = bytes32(msg.data[abs + 32:abs + 64]);
    }

    /// @notice Consume a LISTING block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return host Host node ID that lists the asset.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    function unpackListing(Cur memory cur) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        uint abs = consume(cur, Keys.Listing, 96, 96);
        host = uint(bytes32(msg.data[abs:abs + 32]));
        asset = bytes32(msg.data[abs + 32:abs + 64]);
        meta = bytes32(msg.data[abs + 64:abs + 96]);
    }

    /// @notice Consume a LISTING block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded host, asset, and meta.
    function unpackListingValue(Cur memory cur) internal pure returns (HostAsset memory value) {
        uint abs = consume(cur, Keys.Listing, 96, 96);
        value.host = uint(bytes32(msg.data[abs:abs + 32]));
        value.asset = bytes32(msg.data[abs + 32:abs + 64]);
        value.meta = bytes32(msg.data[abs + 64:abs + 96]);
    }

    /// @notice Consume a NODE block and return the node ID.
    /// @param cur Cursor; advanced past the block.
    /// @return node Node identifier.
    function unpackNode(Cur memory cur) internal pure returns (uint node) {
        uint abs = consume(cur, Keys.Node, 32, 32);
        node = uint(bytes32(msg.data[abs:abs + 32]));
    }

    /// @notice Consume a ROUTE block and return the raw payload as a calldata slice.
    /// The payload length is variable; the returned slice covers the entire payload.
    /// @param cur Cursor; advanced past the block.
    /// @return data Raw route payload bytes.
    function unpackRoute(Cur memory cur) internal pure returns (bytes calldata data) {
        (uint abs, uint next) = expect(cur, cur.i, Keys.Route, 0, 0);
        data = msg.data[abs:cur.offset + next];
        cur.i = next;
    }

    /// @notice Consume a QUERY block and return the raw payload as a calldata slice.
    /// The payload length is variable; the returned slice covers the entire payload.
    /// @param cur Cursor; advanced past the block.
    /// @return data Raw query payload bytes.
    function unpackQuery(Cur memory cur) internal pure returns (bytes calldata data) {
        (uint abs, uint next) = expect(cur, cur.i, Keys.Query, 0, 0);
        data = msg.data[abs:cur.offset + next];
        cur.i = next;
    }

    /// @notice Consume a RESPONSE block and return the raw payload as a calldata slice.
    /// The payload length is variable; the returned slice covers the entire payload.
    /// @param cur Cursor; advanced past the block.
    /// @return data Raw response payload bytes.
    function unpackResponse(Cur memory cur) internal pure returns (bytes calldata data) {
        (uint abs, uint next) = expect(cur, cur.i, Keys.Response, 0, 0);
        data = msg.data[abs:cur.offset + next];
        cur.i = next;
    }

    /// @notice Consume a PATH block and return the raw payload as a calldata slice.
    /// The payload length is variable; the returned slice covers the entire payload.
    /// @param cur Cursor; advanced past the block.
    /// @return data Raw path payload bytes.
    function unpackPath(Cur memory cur) internal pure returns (bytes calldata data) {
        (uint abs, uint next) = expect(cur, cur.i, Keys.Path, 0, 0);
        data = msg.data[abs:cur.offset + next];
        cur.i = next;
    }

    /// @notice Consume a ROUTE block with a single uint payload.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded uint value.
    function unpackRouteUint(Cur memory cur) internal pure returns (uint value) {
        uint abs = consume(cur, Keys.Route, 32, 32);
        value = uint(bytes32(msg.data[abs:abs + 32]));
    }

    /// @notice Consume a QUERY block with a single uint payload.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded uint value.
    function unpackQueryUint(Cur memory cur) internal pure returns (uint value) {
        uint abs = consume(cur, Keys.Query, 32, 32);
        value = uint(bytes32(msg.data[abs:abs + 32]));
    }

    /// @notice Consume a RESPONSE block with a single uint payload.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded uint value.
    function unpackResponseUint(Cur memory cur) internal pure returns (uint value) {
        uint abs = consume(cur, Keys.Response, 32, 32);
        value = uint(bytes32(msg.data[abs:abs + 32]));
    }

    /// @notice Consume a ROUTE block with two uint payload words.
    /// @param cur Cursor; advanced past the block.
    /// @return a First decoded uint.
    /// @return b Second decoded uint.
    function unpackRoute2Uint(Cur memory cur) internal pure returns (uint a, uint b) {
        uint abs = consume(cur, Keys.Route, 64, 64);
        a = uint(bytes32(msg.data[abs:abs + 32]));
        b = uint(bytes32(msg.data[abs + 32:abs + 64]));
    }

    /// @notice Consume a QUERY block with two uint payload words.
    /// @param cur Cursor; advanced past the block.
    /// @return a First decoded uint.
    /// @return b Second decoded uint.
    function unpackQuery2Uint(Cur memory cur) internal pure returns (uint a, uint b) {
        uint abs = consume(cur, Keys.Query, 64, 64);
        a = uint(bytes32(msg.data[abs:abs + 32]));
        b = uint(bytes32(msg.data[abs + 32:abs + 64]));
    }

    /// @notice Consume a RESPONSE block with two uint payload words.
    /// @param cur Cursor; advanced past the block.
    /// @return a First decoded uint.
    /// @return b Second decoded uint.
    function unpackResponse2Uint(Cur memory cur) internal pure returns (uint a, uint b) {
        uint abs = consume(cur, Keys.Response, 64, 64);
        a = uint(bytes32(msg.data[abs:abs + 32]));
        b = uint(bytes32(msg.data[abs + 32:abs + 64]));
    }

    /// @notice Consume a ROUTE block with three uint payload words.
    /// @param cur Cursor; advanced past the block.
    /// @return a First decoded uint.
    /// @return b Second decoded uint.
    /// @return c Third decoded uint.
    function unpackRoute3Uint(Cur memory cur) internal pure returns (uint a, uint b, uint c) {
        uint abs = consume(cur, Keys.Route, 96, 96);
        a = uint(bytes32(msg.data[abs:abs + 32]));
        b = uint(bytes32(msg.data[abs + 32:abs + 64]));
        c = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume a QUERY block with three uint payload words.
    /// @param cur Cursor; advanced past the block.
    /// @return a First decoded uint.
    /// @return b Second decoded uint.
    /// @return c Third decoded uint.
    function unpackQuery3Uint(Cur memory cur) internal pure returns (uint a, uint b, uint c) {
        uint abs = consume(cur, Keys.Query, 96, 96);
        a = uint(bytes32(msg.data[abs:abs + 32]));
        b = uint(bytes32(msg.data[abs + 32:abs + 64]));
        c = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume a RESPONSE block with three uint payload words.
    /// @param cur Cursor; advanced past the block.
    /// @return a First decoded uint.
    /// @return b Second decoded uint.
    /// @return c Third decoded uint.
    function unpackResponse3Uint(Cur memory cur) internal pure returns (uint a, uint b, uint c) {
        uint abs = consume(cur, Keys.Response, 96, 96);
        a = uint(bytes32(msg.data[abs:abs + 32]));
        b = uint(bytes32(msg.data[abs + 32:abs + 64]));
        c = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Consume a ROUTE block with a single bytes32 payload.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded bytes32.
    function unpackRoute32(Cur memory cur) internal pure returns (bytes32 value) {
        uint abs = consume(cur, Keys.Route, 32, 32);
        value = bytes32(msg.data[abs:abs + 32]);
    }

    /// @notice Consume a QUERY block with a single bytes32 payload.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded bytes32.
    function unpackQuery32(Cur memory cur) internal pure returns (bytes32 value) {
        uint abs = consume(cur, Keys.Query, 32, 32);
        value = bytes32(msg.data[abs:abs + 32]);
    }

    /// @notice Consume a RESPONSE block with a single bytes32 payload.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded bytes32.
    function unpackResponse32(Cur memory cur) internal pure returns (bytes32 value) {
        uint abs = consume(cur, Keys.Response, 32, 32);
        value = bytes32(msg.data[abs:abs + 32]);
    }

    /// @notice Consume a ROUTE block with two bytes32 payload words.
    /// @param cur Cursor; advanced past the block.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    function unpackRoute64(Cur memory cur) internal pure returns (bytes32 a, bytes32 b) {
        uint abs = consume(cur, Keys.Route, 64, 64);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
    }

    /// @notice Consume a QUERY block with two bytes32 payload words.
    /// @param cur Cursor; advanced past the block.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    function unpackQuery64(Cur memory cur) internal pure returns (bytes32 a, bytes32 b) {
        uint abs = consume(cur, Keys.Query, 64, 64);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
    }

    /// @notice Consume a RESPONSE block with two bytes32 payload words.
    /// @param cur Cursor; advanced past the block.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    function unpackResponse64(Cur memory cur) internal pure returns (bytes32 a, bytes32 b) {
        uint abs = consume(cur, Keys.Response, 64, 64);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
    }

    /// @notice Consume a ROUTE block with three bytes32 payload words.
    /// @param cur Cursor; advanced past the block.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    /// @return c Third decoded bytes32.
    function unpackRoute96(Cur memory cur) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        uint abs = consume(cur, Keys.Route, 96, 96);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
    }

    /// @notice Consume a QUERY block with three bytes32 payload words.
    /// @param cur Cursor; advanced past the block.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    /// @return c Third decoded bytes32.
    function unpackQuery96(Cur memory cur) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        uint abs = consume(cur, Keys.Query, 96, 96);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
    }

    /// @notice Consume a RESPONSE block with three bytes32 payload words.
    /// @param cur Cursor; advanced past the block.
    /// @return a First decoded bytes32.
    /// @return b Second decoded bytes32.
    /// @return c Third decoded bytes32.
    function unpackResponse96(Cur memory cur) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        uint abs = consume(cur, Keys.Response, 96, 96);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
    }

    /// @notice Consume a CUSTODY block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded host, asset, meta, and amount.
    function unpackCustodyValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        uint abs = consume(cur, Keys.Custody, 128, 128);
        value.host = uint(bytes32(msg.data[abs:abs + 32]));
        value.asset = bytes32(msg.data[abs + 32:abs + 64]);
        value.meta = bytes32(msg.data[abs + 64:abs + 96]);
        value.amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    /// @notice Consume an ALLOCATION block and return its fields as separate values.
    /// @param cur Cursor; advanced past the block.
    /// @return host Host node ID of the allocation.
    /// @return asset Asset identifier.
    /// @return meta Asset metadata slot.
    /// @return amount Allocated amount.
    function unpackAllocation(Cur memory cur) internal pure returns (uint host, bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, Keys.Allocation, 128, 128);
        host = uint(bytes32(msg.data[abs:abs + 32]));
        asset = bytes32(msg.data[abs + 32:abs + 64]);
        meta = bytes32(msg.data[abs + 64:abs + 96]);
        amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    /// @notice Consume an ALLOCATION block and return its fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded host, asset, meta, and amount.
    function unpackAllocationValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        uint abs = consume(cur, Keys.Allocation, 128, 128);
        value.host = uint(bytes32(msg.data[abs:abs + 32]));
        value.asset = bytes32(msg.data[abs + 32:abs + 64]);
        value.meta = bytes32(msg.data[abs + 64:abs + 96]);
        value.amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    /// @notice Consume a TRANSACTION block and return all fields as a struct.
    /// @param cur Cursor; advanced past the block.
    /// @return value Decoded from, to, asset, meta, and amount.
    function unpackTxValue(Cur memory cur) internal pure returns (Tx memory value) {
        uint abs = consume(cur, Keys.Transaction, 160, 160);
        value.from = bytes32(msg.data[abs:abs + 32]);
        value.to = bytes32(msg.data[abs + 32:abs + 64]);
        value.asset = bytes32(msg.data[abs + 64:abs + 96]);
        value.meta = bytes32(msg.data[abs + 96:abs + 128]);
        value.amount = uint(bytes32(msg.data[abs + 128:abs + 160]));
    }

    // -------------------------------------------------------------------------
    // expect* — validate at given position without advancing cursor
    // -------------------------------------------------------------------------

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

    /// @notice Validate an AMOUNT block at position `i` for a specific asset.
    /// Does not advance the cursor.
    /// @param cur Source cursor.
    /// @param i Byte offset of the AMOUNT block.
    /// @param asset Expected asset identifier.
    /// @param meta Expected metadata slot.
    /// @return amount Token amount from the block.
    function expectAmount(Cur memory cur, uint i, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        (uint abs, ) = expect(cur, i, Keys.Amount, 96, 96);
        if (bytes32(msg.data[abs:abs + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[abs + 32:abs + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Validate a BALANCE block at position `i` for a specific asset.
    /// Does not advance the cursor.
    /// @param cur Source cursor.
    /// @param i Byte offset of the BALANCE block.
    /// @param asset Expected asset identifier.
    /// @param meta Expected metadata slot.
    /// @return amount Token amount from the block.
    function expectBalance(Cur memory cur, uint i, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        (uint abs, ) = expect(cur, i, Keys.Balance, 96, 96);
        if (bytes32(msg.data[abs:abs + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[abs + 32:abs + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Validate a MINIMUM block at position `i` for a specific asset.
    /// Does not advance the cursor.
    /// @param cur Source cursor.
    /// @param i Byte offset of the MINIMUM block.
    /// @param asset Expected asset identifier.
    /// @param meta Expected metadata slot.
    /// @return amount Minimum amount from the block.
    function expectMinimum(Cur memory cur, uint i, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        (uint abs, ) = expect(cur, i, Keys.Minimum, 96, 96);
        if (bytes32(msg.data[abs:abs + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[abs + 32:abs + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Validate a MAXIMUM block at position `i` for a specific asset.
    /// Does not advance the cursor.
    /// @param cur Source cursor.
    /// @param i Byte offset of the MAXIMUM block.
    /// @param asset Expected asset identifier.
    /// @param meta Expected metadata slot.
    /// @return amount Maximum amount from the block.
    function expectMaximum(Cur memory cur, uint i, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        (uint abs, ) = expect(cur, i, Keys.Maximum, 96, 96);
        if (bytes32(msg.data[abs:abs + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[abs + 32:abs + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    /// @notice Validate a CUSTODY block at position `i` for a specific host.
    /// Does not advance the cursor.
    /// @param cur Source cursor.
    /// @param i Byte offset of the CUSTODY block.
    /// @param host Expected host node ID.
    /// @return value Decoded asset, meta, and amount (host is not returned; it was validated).
    function expectCustody(Cur memory cur, uint i, uint host) internal pure returns (AssetAmount memory value) {
        (uint abs, ) = expect(cur, i, Keys.Custody, 128, 128);
        if (uint(bytes32(msg.data[abs:abs + 32])) != host) revert UnexpectedValue();
        value.asset = bytes32(msg.data[abs + 32:abs + 64]);
        value.meta = bytes32(msg.data[abs + 64:abs + 96]);
        value.amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    // -------------------------------------------------------------------------
    // require* — validate + advance (like consume with content checks)
    // -------------------------------------------------------------------------

    /// @notice Consume an AUTH block at the current position and verify the command ID.
    /// @param cur Cursor; advanced past the block.
    /// @param cid Expected command ID.
    /// @return deadline Expiry timestamp.
    /// @return proof Raw proof bytes.
    function requireAuth(Cur memory cur, uint cid) internal pure returns (uint deadline, bytes calldata proof) {
        (deadline, proof) = expectAuth(cur, cur.i, cid);
        cur.i += 64 + proof.length;
    }

    /// @notice Consume an AMOUNT block and assert it matches the expected asset and meta.
    /// @param cur Cursor; advanced past the block.
    /// @param asset Expected asset identifier.
    /// @param meta Expected metadata slot.
    /// @return amount Token amount from the block.
    function requireAmount(Cur memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        amount = expectAmount(cur, cur.i, asset, meta);
        cur.i += 104;
    }

    /// @notice Consume a BALANCE block and assert it matches the expected asset and meta.
    /// @param cur Cursor; advanced past the block.
    /// @param asset Expected asset identifier.
    /// @param meta Expected metadata slot.
    /// @return amount Token amount from the block.
    function requireBalance(Cur memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        amount = expectBalance(cur, cur.i, asset, meta);
        cur.i += 104;
    }

    /// @notice Consume a MINIMUM block and assert it matches the expected asset and meta.
    /// @param cur Cursor; advanced past the block.
    /// @param asset Expected asset identifier.
    /// @param meta Expected metadata slot.
    /// @return amount Minimum amount from the block.
    function requireMinimum(Cur memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        amount = expectMinimum(cur, cur.i, asset, meta);
        cur.i += 104;
    }

    /// @notice Consume a MINIMUM block, assert it matches the expected asset and meta, and require `amount` to satisfy it.
    /// @param cur Cursor; advanced past the block.
    /// @param asset Expected asset identifier.
    /// @param meta Expected metadata slot.
    /// @param amount Actual amount that must be at least the minimum from the block.
    function requireMinimum(Cur memory cur, bytes32 asset, bytes32 meta, uint amount) internal pure {
        if (requireMinimum(cur, asset, meta) > amount) revert UnexpectedValue();
    }

    /// @notice Consume a MAXIMUM block and assert it matches the expected asset and meta.
    /// @param cur Cursor; advanced past the block.
    /// @param asset Expected asset identifier.
    /// @param meta Expected metadata slot.
    /// @return amount Maximum amount from the block.
    function requireMaximum(Cur memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        amount = expectMaximum(cur, cur.i, asset, meta);
        cur.i += 104;
    }

    /// @notice Consume a MAXIMUM block, assert it matches the expected asset and meta, and require `amount` to satisfy it.
    /// @param cur Cursor; advanced past the block.
    /// @param asset Expected asset identifier.
    /// @param meta Expected metadata slot.
    /// @param amount Actual amount that must be at most the maximum from the block.
    function requireMaximum(Cur memory cur, bytes32 asset, bytes32 meta, uint amount) internal pure {
        if (requireMaximum(cur, asset, meta) < amount) revert UnexpectedValue();
    }

    /// @notice Consume a CUSTODY block and assert it belongs to the expected host.
    /// @param cur Cursor; advanced past the block.
    /// @param host Expected host node ID.
    /// @return value Decoded asset, meta, and amount.
    function requireCustody(Cur memory cur, uint host) internal pure returns (AssetAmount memory value) {
        value = expectCustody(cur, cur.i, host);
        cur.i += 136;
    }

}
