// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AssetAmount, AccountAmount, HostAmount, Tx} from "../core/Types.sol";
import {Sizes} from "./Schema.sol";
import {Keys} from "./Keys.sol";
import {max32} from "../utils/Utils.sol";

/// @notice Sequential block stream writer backed by a pre-allocated memory buffer.
struct Writer {
    /// @dev Current write position: number of bytes written so far.
    uint i;
    /// @dev Logical buffer capacity in bytes; writers should not advance past this limit.
    uint end;
    /// @dev Destination buffer. Physical capacity may be padded up to a full 32-byte word;
    ///      final length is set to `i` by `finish`.
    bytes dst;
}

// Fixed-point scaling denominator for output-count allocation.
// A `scaledRatio` of `ALLOC_SCALE` means 1:1 (one output block per input block).
// `2 * ALLOC_SCALE` means 2:1; non-integer ratios revert with `BadWriterRatio`.
uint constant ALLOC_SCALE = 10_000;

/// @title Writers
/// @notice Response block stream builder for the rootzero protocol.
/// Allocates a fixed-size memory buffer up front and writes binary-encoded
/// blocks into it sequentially. Physical allocation is rounded up to whole
/// 32-byte words for scratch space, while `Writer.end` tracks the logical
/// requested capacity. Call `finish` to trim the buffer to the number of
/// bytes actually written and return the result.
library Writers {
    /// @dev `append` or a `write*` function tried to write past the end of `dst`.
    error WriterOverflow();
    /// @dev `finish` called with a writer whose `i` exceeds `dst.length`.
    error IncompleteWriter();
    /// @dev An alloc function received a zero count, or `finish` found no bytes written.
    error EmptyRequest();
    /// @dev `scaledRatio * count` is not evenly divisible by `ALLOC_SCALE`.
    error BadWriterRatio();
    /// @dev A fixed-width low-level writer received an invalid final-word keep length.
    error InvalidKeep();

    // -------------------------------------------------------------------------
    // Allocation helpers
    // -------------------------------------------------------------------------

    /// @notice Allocate a writer with a logical byte capacity.
    /// The backing buffer is rounded up to whole 32-byte words, while
    /// `writer.end` remains the exact logical byte capacity requested.
    /// @param len Number of logical bytes to pre-allocate.
    /// @return writer Freshly allocated writer positioned at index 0.
    function alloc(uint len) internal pure returns (Writer memory writer) {
        // Extra 32 bytes ensure mstore in write/append32 never reaches past allocated memory,
        // even when a sub-word packed write starts within the last 31 bytes of the logical region.
        uint padded = ((len + 31) & ~uint(31)) + 32;
        writer = Writer({i: 0, end: len, dst: new bytes(padded)});
    }

    /// @notice Core allocation routine used by all counted `alloc*` helpers.
    /// Computes `(count * scaledRatio / ALLOC_SCALE) * blockLen` and allocates that many bytes.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output-to-input ratio in `ALLOC_SCALE` units.
    /// @param blockLen Logical byte size of each output block (including 8-byte header).
    /// @return writer Allocated writer.
    function allocFromScaledCount(
        uint count,
        uint scaledRatio,
        uint blockLen
    ) internal pure returns (Writer memory writer) {
        if (count == 0) revert EmptyRequest();
        uint scaledCount = count * scaledRatio;
        if (scaledCount % ALLOC_SCALE != 0) revert BadWriterRatio();
        uint len = (scaledCount / ALLOC_SCALE) * blockLen;
        writer = alloc(len);
    }

    /// @notice Allocate a writer sized for exactly `count` dynamic blocks with a shared payload length.
    /// Each block reserves `Sizes.Header + payloadLen` bytes.
    /// @param count Number of blocks to allocate space for.
    /// @param payloadLen Payload byte length for each block.
    /// @return writer Allocated writer.
    function allocBytes(uint count, uint payloadLen) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, Sizes.Header + payloadLen);
    }

    /// @notice Allocate a writer sized for exactly `count` 32-byte-payload blocks (1:1 ratio).
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated writer.
    function alloc32s(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, Sizes.B32);
    }

    /// @notice Allocate a writer sized for exactly `count` 64-byte-payload blocks (1:1 ratio).
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated writer.
    function alloc64s(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, Sizes.B64);
    }

    /// @notice Allocate a writer sized for exactly `count` 96-byte-payload blocks (1:1 ratio).
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated writer.
    function alloc96s(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, Sizes.B96);
    }

    /// @notice Allocate a writer sized for exactly `count` 128-byte-payload blocks (1:1 ratio).
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated writer.
    function alloc128s(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, Sizes.B128);
    }

    /// @notice Allocate a writer sized for exactly `count` 160-byte-payload blocks (1:1 ratio).
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated writer.
    function alloc160s(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, Sizes.B160);
    }

    /// @notice Allocate a writer for dynamic blocks with a shared payload length and custom output ratio.
    /// Each block reserves `Sizes.Header + payloadLen` bytes.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units.
    /// @param payloadLen Payload byte length for each block.
    /// @return writer Allocated writer.
    function allocScaledBytes(
        uint count,
        uint scaledRatio,
        uint payloadLen
    ) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, scaledRatio, Sizes.Header + payloadLen);
    }

    /// @notice Allocate a writer for 32-byte-payload blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units.
    /// @return writer Allocated writer.
    function allocScaled32s(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, scaledRatio, Sizes.B32);
    }

    /// @notice Allocate a writer for 64-byte-payload blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units.
    /// @return writer Allocated writer.
    function allocScaled64s(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, scaledRatio, Sizes.B64);
    }

    /// @notice Allocate a writer for 96-byte-payload blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units.
    /// @return writer Allocated writer.
    function allocScaled96s(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, scaledRatio, Sizes.B96);
    }

    /// @notice Allocate a writer for 128-byte-payload blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units.
    /// @return writer Allocated writer.
    function allocScaled128s(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, scaledRatio, Sizes.B128);
    }

    /// @notice Allocate a writer for 160-byte-payload blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units.
    /// @return writer Allocated writer.
    function allocScaled160s(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, scaledRatio, Sizes.B160);
    }

    /// @notice Allocate a writer sized for exactly `count` STATUS form blocks.
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocStatuses(uint count) internal pure returns (Writer memory writer) {
        return alloc32s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` ASSET blocks (1:1 ratio).
    /// @param count Number of asset blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocAssets(uint count) internal pure returns (Writer memory writer) {
        return alloc64s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` AMOUNT blocks (1:1 ratio).
    /// @param count Number of amount blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocAmounts(uint count) internal pure returns (Writer memory writer) {
        return alloc96s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` BALANCE blocks (1:1 ratio).
    /// @param count Number of balance blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocBalances(uint count) internal pure returns (Writer memory writer) {
        return alloc96s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` ACCOUNT_AMOUNT form blocks (1:1 ratio).
    /// @param count Number of account amount blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocAccountAmounts(uint count) internal pure returns (Writer memory writer) {
        return alloc128s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` CUSTODY blocks (1:1 ratio).
    /// @param count Number of custody blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocCustodies(uint count) internal pure returns (Writer memory writer) {
        return alloc128s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` TRANSACTION blocks (1:1 ratio).
    /// @param count Number of transaction blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocTransactions(uint count) internal pure returns (Writer memory writer) {
        return alloc160s(count);
    }

    /// @notice Allocate a writer for ASSET blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units
    ///        (e.g. `ALLOC_SCALE` = 1:1, `2 * ALLOC_SCALE` = 2:1).
    /// @return writer Allocated writer.
    function allocScaledAssets(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocScaled64s(count, scaledRatio);
    }

    /// @notice Allocate a writer for AMOUNT blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units
    ///        (e.g. `ALLOC_SCALE` = 1:1, `2 * ALLOC_SCALE` = 2:1).
    /// @return writer Allocated writer.
    function allocScaledAmounts(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocScaled96s(count, scaledRatio);
    }

    /// @notice Allocate a writer for BALANCE blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units
    ///        (e.g. `ALLOC_SCALE` = 1:1, `2 * ALLOC_SCALE` = 2:1).
    /// @return writer Allocated writer.
    function allocScaledBalances(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocScaled96s(count, scaledRatio);
    }

    /// @notice Allocate a writer for CUSTODY blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier in `ALLOC_SCALE` units.
    /// @return writer Allocated writer.
    function allocScaledCustodies(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocScaled128s(count, scaledRatio);
    }

    // -------------------------------------------------------------------------
    // Fixed-width write helpers
    // -------------------------------------------------------------------------

    /// @notice Write a low-level block header and return its memory pointer.
    /// The header occupies the most-significant 8 bytes of the first stored word.
    /// @param dst Destination buffer.
    /// @param i Write offset within `dst`.
    /// @param key Four-byte block type identifier.
    /// @param len Payload byte length.
    /// @return p Memory pointer to the start of the block header within `dst`.
    function writeHeader(bytes memory dst, uint i, bytes4 key, uint32 len) private pure returns (uint p) {
        uint header = (uint(uint32(key)) << 224) | (uint(len) << 192);
        assembly ("memory-safe") {
            p := add(add(dst, 0x20), i)
            mstore(p, header)
        }
    }

    /// @notice Commit a logical writer advance after a low-level write.
    /// @dev Low-level write helpers validate the padded backing buffer. This
    ///      enforces the caller-requested logical capacity recorded in `end`.
    function commit(Writer memory writer, uint next) private pure {
        if (next > writer.end) revert WriterOverflow();
        writer.i = next;
    }

    /// @notice Write raw bytes directly into `dst` at byte offset `i` without a block header.
    /// @param dst Destination buffer.
    /// @param i Write offset within `dst`.
    /// @param data Bytes to copy.
    /// @return next Byte offset immediately after the copied bytes.
    function write(bytes memory dst, uint i, bytes memory data) internal pure returns (uint next) {
        next = i + data.length;
        if (next > dst.length) revert WriterOverflow();
        assembly ("memory-safe") {
            mcopy(add(add(dst, 0x20), i), add(data, 0x20), mload(data))
        }
    }

    /// @notice Write a raw 32-byte word directly into `dst` at byte offset `i` without a block header.
    /// `keep` controls how many leading bytes of the word are included in the logical write.
    /// @param dst Destination buffer; must have at least `i + 32` bytes.
    /// @param i Write offset within `dst`.
    /// @param value Word to write.
    /// @param keep Number of bytes to keep from the word (1..32).
    /// @return next Byte offset immediately after the written bytes.
    function write32(bytes memory dst, uint i, bytes32 value, uint keep) internal pure returns (uint next) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        if (i + 32 > dst.length) revert WriterOverflow();
        next = i + keep;
        assembly ("memory-safe") {
            mstore(add(add(dst, 0x20), i), value)
        }
    }

    /// @notice Write two raw 32-byte words directly into `dst` at byte offset `i` without a block header.
    /// `keep` controls how many leading bytes of the final word are included in the logical write.
    /// @param dst Destination buffer; must have at least `i + 64` bytes.
    /// @param i Write offset within `dst`.
    /// @param a First word to write.
    /// @param b Second word to write.
    /// @param keep Number of bytes to keep from the final word (1..32).
    /// @return next Byte offset immediately after the written bytes.
    function write64(bytes memory dst, uint i, bytes32 a, bytes32 b, uint keep) internal pure returns (uint next) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        if (i + 64 > dst.length) revert WriterOverflow();
        next = i + 32 + keep;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, a)
            mstore(add(p, 0x20), b)
        }
    }

    /// @notice Write three raw 32-byte words directly into `dst` at byte offset `i` without a block header.
    /// `keep` controls how many leading bytes of the final word are included in the logical write.
    /// @param dst Destination buffer; must have at least `i + 96` bytes.
    /// @param i Write offset within `dst`.
    /// @param a First word to write.
    /// @param b Second word to write.
    /// @param c Third word to write.
    /// @param keep Number of bytes to keep from the final word (1..32).
    /// @return next Byte offset immediately after the written bytes.
    function write96(
        bytes memory dst,
        uint i,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        uint keep
    ) internal pure returns (uint next) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        if (i + 96 > dst.length) revert WriterOverflow();
        next = i + 64 + keep;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, a)
            mstore(add(p, 0x20), b)
            mstore(add(p, 0x40), c)
        }
    }

    /// @notice Write a dynamic block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.Header + data.length` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param data Dynamic payload bytes.
    /// @return next Byte offset immediately after the written block.
    function writeBlock(bytes memory dst, uint i, bytes4 key, bytes memory data) internal pure returns (uint next) {
        next = i + Sizes.Header + data.length;
        if (next > dst.length) revert WriterOverflow();
        uint p = writeHeader(dst, i, key, uint32(max32(data.length)));
        assembly ("memory-safe") {
            mcopy(add(p, 0x08), add(data, 0x20), mload(data))
        }
    }

    /// @notice Write a fixed-width 32-byte-payload block directly into `dst` at byte offset `i`.
    /// `keep` controls how many leading bytes of the final payload word are included.
    /// Writes still use full-word stores, so `dst` must have capacity for the untrimmed block.
    /// @param dst Destination buffer; must have at least `i + Sizes.B32` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    /// @return next Byte offset immediately after the written block.
    function writeBlock32(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        uint keep
    ) internal pure returns (uint next) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        if (i + Sizes.B32 > dst.length) revert WriterOverflow();
        uint len = keep;
        next = i + Sizes.Header + len;
        uint p = writeHeader(dst, i, key, uint32(len));
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
        }
    }

    /// @notice Write a fixed-width 64-byte-payload block directly into `dst` at byte offset `i`.
    /// `keep` controls how many leading bytes of the final payload word are included.
    /// Writes still use full-word stores, so `dst` must have capacity for the untrimmed block.
    /// @param dst Destination buffer; must have at least `i + Sizes.B64` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    /// @return next Byte offset immediately after the written block.
    function writeBlock64(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        uint keep
    ) internal pure returns (uint next) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        if (i + Sizes.B64 > dst.length) revert WriterOverflow();
        uint len = 32 + keep;
        next = i + Sizes.Header + len;
        uint p = writeHeader(dst, i, key, uint32(len));
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
        }
    }

    /// @notice Write a fixed-width 96-byte-payload block directly into `dst` at byte offset `i`.
    /// `keep` controls how many leading bytes of the final payload word are included.
    /// Writes still use full-word stores, so `dst` must have capacity for the untrimmed block.
    /// @param dst Destination buffer; must have at least `i + Sizes.B96` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    /// @return next Byte offset immediately after the written block.
    function writeBlock96(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        uint keep
    ) internal pure returns (uint next) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        if (i + Sizes.B96 > dst.length) revert WriterOverflow();
        uint len = 64 + keep;
        next = i + Sizes.Header + len;
        uint p = writeHeader(dst, i, key, uint32(len));
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
            mstore(add(p, 0x48), c)
        }
    }

    /// @notice Write a fixed-width 128-byte-payload block directly into `dst` at byte offset `i`.
    /// `keep` controls how many leading bytes of the final payload word are included.
    /// Writes still use full-word stores, so `dst` must have capacity for the untrimmed block.
    /// @param dst Destination buffer; must have at least `i + Sizes.B128` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    /// @return next Byte offset immediately after the written block.
    function writeBlock128(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        uint keep
    ) internal pure returns (uint next) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        if (i + Sizes.B128 > dst.length) revert WriterOverflow();
        uint len = 96 + keep;
        next = i + Sizes.Header + len;
        uint p = writeHeader(dst, i, key, uint32(len));
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
            mstore(add(p, 0x48), c)
            mstore(add(p, 0x68), d)
        }
    }

    /// @notice Write a fixed-width 160-byte-payload block directly into `dst` at byte offset `i`.
    /// `keep` controls how many leading bytes of the final payload word are included.
    /// Writes still use full-word stores, so `dst` must have capacity for the untrimmed block.
    /// @param dst Destination buffer; must have at least `i + Sizes.B160` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @param e Fifth payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    /// @return next Byte offset immediately after the written block.
    function writeBlock160(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        bytes32 e,
        uint keep
    ) internal pure returns (uint next) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        if (i + Sizes.B160 > dst.length) revert WriterOverflow();
        uint len = 128 + keep;
        next = i + Sizes.Header + len;
        uint p = writeHeader(dst, i, key, uint32(len));
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
            mstore(add(p, 0x48), c)
            mstore(add(p, 0x68), d)
            mstore(add(p, 0x88), e)
        }
    }

    /// @notice Write a dynamic block with a fixed 32-byte head word.
    /// @param dst Destination buffer; must have at least `i + Sizes.B32 + tail.length` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a Fixed head word.
    /// @param tail Dynamic payload bytes appended after the head.
    /// @return next Byte offset immediately after the written block.
    function writeBlockHead32(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes memory tail
    ) internal pure returns (uint next) {
        uint len = 32 + tail.length;
        next = i + Sizes.Header + len;
        if (i + Sizes.B32 + tail.length > dst.length) revert WriterOverflow();
        uint p = writeHeader(dst, i, key, uint32(max32(len)));
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
            mcopy(add(p, 0x28), add(tail, 0x20), mload(tail))
        }
    }

    /// @notice Write a dynamic block with a fixed 64-byte head.
    /// @param dst Destination buffer; must have at least `i + Sizes.B64 + tail.length` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First fixed head word.
    /// @param b Second fixed head word.
    /// @param tail Dynamic payload bytes appended after the head.
    /// @return next Byte offset immediately after the written block.
    function writeBlockHead64(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes memory tail
    ) internal pure returns (uint next) {
        uint len = 64 + tail.length;
        next = i + Sizes.Header + len;
        if (i + Sizes.B64 + tail.length > dst.length) revert WriterOverflow();
        uint p = writeHeader(dst, i, key, uint32(max32(len)));
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
            mcopy(add(p, 0x48), add(tail, 0x20), mload(tail))
        }
    }

    // -------------------------------------------------------------------------
    // Append helpers
    // -------------------------------------------------------------------------

    /// @notice Append arbitrary bytes to the writer.
    /// @param writer Destination writer; `i` is advanced by `data.length`.
    /// @param data Bytes to append.
    function append(Writer memory writer, bytes memory data) internal pure {
        commit(writer, write(writer.dst, writer.i, data));
    }

    /// @notice Append a raw 32-byte word without a block header.
    /// @param writer Destination writer; `i` is advanced by `keep`.
    /// @param value Word to append.
    /// @param keep Number of bytes to keep from the word (1..32).
    function append32(Writer memory writer, bytes32 value, uint keep) internal pure {
        commit(writer, write32(writer.dst, writer.i, value, keep));
    }

    /// @notice Append two raw 32-byte words without a block header.
    /// @param writer Destination writer; `i` is advanced by `32 + keep`.
    /// @param a First word to append.
    /// @param b Second word to append.
    /// @param keep Number of bytes to keep from the final word (1..32).
    function append64(Writer memory writer, bytes32 a, bytes32 b, uint keep) internal pure {
        commit(writer, write64(writer.dst, writer.i, a, b, keep));
    }

    /// @notice Append three raw 32-byte words without a block header.
    /// @param writer Destination writer; `i` is advanced by `64 + keep`.
    /// @param a First word to append.
    /// @param b Second word to append.
    /// @param c Third word to append.
    /// @param keep Number of bytes to keep from the final word (1..32).
    function append96(Writer memory writer, bytes32 a, bytes32 b, bytes32 c, uint keep) internal pure {
        commit(writer, write96(writer.dst, writer.i, a, b, c, keep));
    }

    /// @notice Append a dynamic block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Header + data.length`.
    /// @param key Block type key.
    /// @param data Dynamic payload bytes.
    function appendBlock(Writer memory writer, bytes4 key, bytes memory data) internal pure {
        commit(writer, writeBlock(writer.dst, writer.i, key, data));
    }

    /// @notice Append a fixed-width 32-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the kept logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function appendBlock32(Writer memory writer, bytes4 key, bytes32 a, uint keep) internal pure {
        commit(writer, writeBlock32(writer.dst, writer.i, key, a, keep));
    }

    /// @notice Append a fixed-width 64-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the kept logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function appendBlock64(Writer memory writer, bytes4 key, bytes32 a, bytes32 b, uint keep) internal pure {
        commit(writer, writeBlock64(writer.dst, writer.i, key, a, b, keep));
    }

    /// @notice Append a fixed-width 96-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the kept logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function appendBlock96(Writer memory writer, bytes4 key, bytes32 a, bytes32 b, bytes32 c, uint keep) internal pure {
        commit(writer, writeBlock96(writer.dst, writer.i, key, a, b, c, keep));
    }

    /// @notice Append a fixed-width 128-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the kept logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function appendBlock128(
        Writer memory writer,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        uint keep
    ) internal pure {
        commit(writer, writeBlock128(writer.dst, writer.i, key, a, b, c, d, keep));
    }

    /// @notice Append a fixed-width 160-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the kept logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @param e Fifth payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function appendBlock160(
        Writer memory writer,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        bytes32 e,
        uint keep
    ) internal pure {
        commit(writer, writeBlock160(writer.dst, writer.i, key, a, b, c, d, e, keep));
    }

    /// @notice Append a dynamic block with a fixed 32-byte head word.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B32 + tail.length`.
    /// @param key Block type key.
    /// @param a Fixed head word.
    /// @param tail Dynamic payload bytes appended after the head.
    function appendBlockHead32(Writer memory writer, bytes4 key, bytes32 a, bytes memory tail) internal pure {
        commit(writer, writeBlockHead32(writer.dst, writer.i, key, a, tail));
    }

    /// @notice Append a dynamic block with a fixed 64-byte head.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B64 + tail.length`.
    /// @param key Block type key.
    /// @param a First fixed head word.
    /// @param b Second fixed head word.
    /// @param tail Dynamic payload bytes appended after the head.
    function appendBlockHead64(
        Writer memory writer,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes memory tail
    ) internal pure {
        commit(writer, writeBlockHead64(writer.dst, writer.i, key, a, b, tail));
    }

    /// @notice Append a STATUS form block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B32`.
    /// @param ok Status value to encode.
    function appendStatus(Writer memory writer, bool ok) internal pure {
        commit(writer, writeBlock32(writer.dst, writer.i, Keys.Status, ok ? bytes32(uint(1)) : bytes32(0), 32));
    }

    /// @notice Append a BALANCE block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Amount`.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendBalance(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
        commit(writer, writeBlock96(writer.dst, writer.i, Keys.Balance, asset, meta, bytes32(amount), 32));
    }

    /// @notice Append a BALANCE block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Balance`.
    /// @param value Balance fields to encode.
    function appendBalance(Writer memory writer, AssetAmount memory value) internal pure {
        commit(
            writer,
            writeBlock96(writer.dst, writer.i, Keys.Balance, value.asset, value.meta, bytes32(value.amount), 32)
        );
    }

    /// @notice Append an AMOUNT block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Amount`.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendAmount(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
        commit(writer, writeBlock96(writer.dst, writer.i, Keys.Amount, asset, meta, bytes32(amount), 32));
    }

    /// @notice Append an AMOUNT block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Balance`.
    /// @param value Amount fields to encode.
    function appendAmount(Writer memory writer, AssetAmount memory value) internal pure {
        commit(
            writer,
            writeBlock96(writer.dst, writer.i, Keys.Amount, value.asset, value.meta, bytes32(value.amount), 32)
        );
    }

    /// @notice Append an ACCOUNT_AMOUNT form block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B128`.
    /// @param account Account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendAccountAmount(
        Writer memory writer,
        bytes32 account,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) internal pure {
        commit(
            writer,
            writeBlock128(writer.dst, writer.i, Keys.AccountAmount, account, asset, meta, bytes32(amount), 32)
        );
    }

    /// @notice Append an ACCOUNT_AMOUNT form block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B128`.
    /// @param value Account amount fields to encode.
    function appendAccountAmount(Writer memory writer, AccountAmount memory value) internal pure {
        commit(
            writer,
            writeBlock128(
                writer.dst,
                writer.i,
                Keys.AccountAmount,
                value.account,
                value.asset,
                value.meta,
                bytes32(value.amount),
                32
            )
        );
    }

    /// @notice Append an ASSET block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B64`.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    function appendAsset(Writer memory writer, bytes32 asset, bytes32 meta) internal pure {
        commit(writer, writeBlock64(writer.dst, writer.i, Keys.Asset, asset, meta, 32));
    }

    /// @notice Append a BOUNTY block to the writer.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Bounty`.
    /// @param amount Relayer reward amount.
    /// @param relayer Relayer account identifier.
    function appendBounty(Writer memory writer, uint amount, bytes32 relayer) internal pure {
        commit(writer, writeBlock64(writer.dst, writer.i, Keys.Bounty, bytes32(amount), relayer, 32));
    }

    /// @notice Append a CUSTODY block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.HostAmount`.
    /// @param host Host node ID.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendCustody(Writer memory writer, uint host, bytes32 asset, bytes32 meta, uint amount) internal pure {
        commit(
            writer,
            writeBlock128(writer.dst, writer.i, Keys.Custody, bytes32(host), asset, meta, bytes32(amount), 32)
        );
    }

    /// @notice Append a CUSTODY block from a host and asset amount.
    /// @param writer Destination writer; `i` is advanced by `Sizes.HostAmount`.
    /// @param host Host node ID.
    /// @param value Custody fields to encode.
    function appendCustody(Writer memory writer, uint host, AssetAmount memory value) internal pure {
        commit(
            writer,
            writeBlock128(
                writer.dst,
                writer.i,
                Keys.Custody,
                bytes32(host),
                value.asset,
                value.meta,
                bytes32(value.amount),
                32
            )
        );
    }

    /// @notice Append a CUSTODY block from a host amount struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.HostAmount`.
    /// @param value Custody fields to encode.
    function appendCustody(Writer memory writer, HostAmount memory value) internal pure {
        commit(
            writer,
            writeBlock128(
                writer.dst,
                writer.i,
                Keys.Custody,
                bytes32(value.host),
                value.asset,
                value.meta,
                bytes32(value.amount),
                32
            )
        );
    }

    /// @notice Append a TRANSACTION block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Transaction`.
    /// @param value Transfer record fields to encode.
    function appendTransaction(Writer memory writer, Tx memory value) internal pure {
        commit(
            writer,
            writeBlock160(
                writer.dst,
                writer.i,
                Keys.Transaction,
                bytes32(value.from),
                bytes32(value.to),
                value.asset,
                value.meta,
                bytes32(value.amount),
                32
            )
        );
    }

    // -------------------------------------------------------------------------
    // Finalisation
    // -------------------------------------------------------------------------

    /// @notice Trim `dst` to the number of bytes actually written and return it.
    /// Sets the `bytes` length slot in memory to `writer.i` without copying.
    /// @param writer Completed writer.
    /// @return out The written block stream; length equals `writer.i`.
    function finish(Writer memory writer) internal pure returns (bytes memory out) {
        if (writer.i == 0) revert EmptyRequest();
        if (writer.i > writer.end || writer.i > writer.dst.length) revert IncompleteWriter();
        out = writer.dst;
        // Overwrite the memory length word of `out` with the actual written length.
        assembly ("memory-safe") {
            mstore(out, mload(writer))
        }
    }
}
