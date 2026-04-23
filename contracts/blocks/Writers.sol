// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AssetAmount, Tx, UserAmount, UserPosition} from "../core/Types.sol";
import {Keys, Sizes} from "./Schema.sol";

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
    /// @dev Block payload length exceeds `uint32` max; cannot be encoded in the 4-byte header field.
    error BlockLengthOverflow();
    /// @dev `scaledRatio * count` is not evenly divisible by `ALLOC_SCALE`.
    error BadWriterRatio();
    /// @dev A fixed-width low-level writer received a tail trim larger than 31 bytes.
    error InvalidTrim();

    // -------------------------------------------------------------------------
    // Low-level write preparation
    // -------------------------------------------------------------------------

    /// @notice Encode an 8-byte block header into a single uint for efficient `mstore`.
    /// The header occupies the most-significant 8 bytes; the payload starts at `offset + 8`.
    /// @param key Four-byte block type identifier.
    /// @param len Payload byte length.
    /// @return Packed header as a uint (key in bits [255:224], len in bits [223:192]).
    function toBlockHeader(bytes4 key, uint len) internal pure returns (uint) {
        if (len > type(uint32).max) revert BlockLengthOverflow();
        return (uint(uint32(key)) << 224) | (uint(uint32(len)) << 192);
    }

    /// @notice Prepare a low-level block write by validating sizes, writing the header,
    /// and returning the payload pointer.
    /// The header occupies the most-significant 8 bytes of the first stored word.
    /// `trim` removes bytes from the end of the payload, while `reserveLen`
    /// is the physical space that may be touched.
    /// @param dst Destination buffer.
    /// @param i Write offset within `dst`.
    /// @param key Four-byte block type identifier.
    /// @param payloadLen Untrimmed payload byte length.
    /// @param trim Number of bytes to trim from the end of the payload (0..31).
    /// @param reserveLen Physical byte span that may be written starting at `i`, including the header.
    /// @return next Logical byte offset immediately after the written block.
    /// @return p Memory pointer to the start of the block header within `dst`.
    function prepareWrite(
        bytes memory dst,
        uint i,
        bytes4 key,
        uint payloadLen,
        uint trim,
        uint reserveLen
    ) private pure returns (uint next, uint p) {
        if (trim > 31) revert InvalidTrim();
        payloadLen -= trim;
        next = i + Sizes.Header + payloadLen;
        if (i + reserveLen > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(key, payloadLen);
        assembly ("memory-safe") {
            p := add(add(dst, 0x20), i)
            mstore(p, header)
        }
    }

    // -------------------------------------------------------------------------
    // Host-qualified asset amounts
    // -------------------------------------------------------------------------

    /// @notice Allocate a writer with a logical byte capacity.
    /// The backing buffer is rounded up to whole 32-byte words, while
    /// `writer.end` remains the exact logical byte capacity requested.
    /// @param len Number of logical bytes to pre-allocate.
    /// @return writer Freshly allocated writer positioned at index 0.
    function alloc(uint len) internal pure returns (Writer memory writer) {
        uint padded = (len + 31) & ~uint(31);
        writer = Writer({i: 0, end: len, dst: new bytes(padded)});
    }

    /// @notice Allocate a writer sized for exactly `count` BALANCE blocks (1:1 ratio).
    /// @param count Number of balance blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocBalances(uint count) internal pure returns (Writer memory writer) {
        return alloc96s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` USER_POSITION blocks (1:1 ratio).
    /// @param count Number of user-position blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocUserPositions(uint count) internal pure returns (Writer memory writer) {
        return alloc96s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` USER_AMOUNT blocks (1:1 ratio).
    /// @param count Number of user-amount blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocUserAmounts(uint count) internal pure returns (Writer memory writer) {
        return alloc128s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` AMOUNT blocks (1:1 ratio).
    /// @param count Number of amount blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocAmounts(uint count) internal pure returns (Writer memory writer) {
        return alloc96s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` ASSET blocks (1:1 ratio).
    /// @param count Number of asset blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocAssets(uint count) internal pure returns (Writer memory writer) {
        return alloc64s(count);
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

    /// @notice Allocate a writer for BALANCE blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units
    ///        (e.g. `ALLOC_SCALE` = 1:1, `2 * ALLOC_SCALE` = 2:1).
    /// @return writer Allocated writer.
    function allocScaledBalances(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocScaled96s(count, scaledRatio);
    }

    /// @notice Allocate a writer for POSITION blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units.
    /// @return writer Allocated writer.
    function allocScaledPositions(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocScaled96s(count, scaledRatio);
    }

    /// @notice Allocate a writer for AMOUNT blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units
    ///        (e.g. `ALLOC_SCALE` = 1:1, `2 * ALLOC_SCALE` = 2:1).
    /// @return writer Allocated writer.
    function allocScaledAmounts(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocScaled96s(count, scaledRatio);
    }

    /// @notice Allocate a writer for ASSET blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units
    ///        (e.g. `ALLOC_SCALE` = 1:1, `2 * ALLOC_SCALE` = 2:1).
    /// @return writer Allocated writer.
    function allocScaledAssets(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocScaled64s(count, scaledRatio);
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

    /// @notice Allocate a writer sized for exactly `count` TRANSACTION blocks (1:1 ratio).
    /// @param count Number of transaction blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocTxs(uint count) internal pure returns (Writer memory writer) {
        return alloc160s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` CUSTODY_AT blocks (1:1 ratio).
    /// @param count Number of custody-at blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocCustodies(uint count) internal pure returns (Writer memory writer) {
        return alloc128s(count);
    }

    /// @notice Allocate a writer for CUSTODY_AT blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier in `ALLOC_SCALE` units.
    /// @return writer Allocated writer.
    function allocScaledCustodies(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocScaled128s(count, scaledRatio);
    }

    /// @notice Core allocation routine used by all typed `alloc*` helpers.
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

    // -------------------------------------------------------------------------
    // Fixed-width write helpers
    // -------------------------------------------------------------------------

    /// @notice Write a raw 32-byte word directly into `dst` at byte offset `i` without a block header.
    /// `trim` shortens the logical write by removing bytes from the end of the word.
    /// @param dst Destination buffer; must have at least `i + 32` bytes.
    /// @param i Write offset within `dst`.
    /// @param value Word to write.
    /// @param trim Number of bytes to trim from the end of the word (0..31).
    /// @return next Byte offset immediately after the written bytes.
    function write32Raw(bytes memory dst, uint i, bytes32 value, uint trim) internal pure returns (uint next) {
        if (trim > 31) revert InvalidTrim();
        if (i + 32 > dst.length) revert WriterOverflow();
        next = i + 32 - trim;
        assembly ("memory-safe") {
            mstore(add(add(dst, 0x20), i), value)
        }
    }

    /// @notice Write a fixed-width 32-byte-payload block directly into `dst` at byte offset `i`.
    /// `trim` shortens the logical payload by removing bytes from the end of the final word.
    /// Writes still use full-word stores, so `dst` must have capacity for the untrimmed block.
    /// @param dst Destination buffer; must have at least `i + Sizes.B32` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param trim Number of bytes to trim from the end of the payload (0..31).
    /// @return next Byte offset immediately after the written block.
    function write32(bytes memory dst, uint i, bytes4 key, bytes32 a, uint trim) internal pure returns (uint next) {
        uint p;
        (next, p) = prepareWrite(dst, i, key, 32, trim, Sizes.B32);
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
        }
    }

    /// @notice Write an ABI-style boolean as a 32-byte scalar payload block.
    /// Encodes `false` as `bytes32(0)` and `true` as `bytes32(uint(1))`.
    /// @param dst Destination buffer; must have at least `i + Sizes.B32` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param value Boolean value to encode.
    /// @return next Byte offset immediately after the written block.
    function writeBool(bytes memory dst, uint i, bytes4 key, bool value) internal pure returns (uint next) {
        return write32(dst, i, key, value ? bytes32(uint(1)) : bytes32(0), 0);
    }

    /// @notice Write a fixed-width 64-byte-payload block directly into `dst` at byte offset `i`.
    /// `trim` shortens the logical payload by removing bytes from the end of the final word.
    /// Writes still use full-word stores, so `dst` must have capacity for the untrimmed block.
    /// @param dst Destination buffer; must have at least `i + Sizes.B64` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param trim Number of bytes to trim from the end of the payload (0..31).
    /// @return next Byte offset immediately after the written block.
    function write64(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        uint trim
    ) internal pure returns (uint next) {
        uint p;
        (next, p) = prepareWrite(dst, i, key, 64, trim, Sizes.B64);
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
        }
    }

    /// @notice Write a fixed-width 96-byte-payload block directly into `dst` at byte offset `i`.
    /// `trim` shortens the logical payload by removing bytes from the end of the final word.
    /// Writes still use full-word stores, so `dst` must have capacity for the untrimmed block.
    /// @param dst Destination buffer; must have at least `i + Sizes.B96` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param trim Number of bytes to trim from the end of the payload (0..31).
    /// @return next Byte offset immediately after the written block.
    function write96(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        uint trim
    ) internal pure returns (uint next) {
        uint p;
        (next, p) = prepareWrite(dst, i, key, 96, trim, Sizes.B96);
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
            mstore(add(p, 0x48), c)
        }
    }

    /// @notice Write a fixed-width 128-byte-payload block directly into `dst` at byte offset `i`.
    /// `trim` shortens the logical payload by removing bytes from the end of the final word.
    /// Writes still use full-word stores, so `dst` must have capacity for the untrimmed block.
    /// @param dst Destination buffer; must have at least `i + Sizes.B128` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @param trim Number of bytes to trim from the end of the payload (0..31).
    /// @return next Byte offset immediately after the written block.
    function write128(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        uint trim
    ) internal pure returns (uint next) {
        uint p;
        (next, p) = prepareWrite(dst, i, key, 128, trim, Sizes.B128);
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
            mstore(add(p, 0x48), c)
            mstore(add(p, 0x68), d)
        }
    }

    /// @notice Write a fixed-width 160-byte-payload block directly into `dst` at byte offset `i`.
    /// `trim` shortens the logical payload by removing bytes from the end of the final word.
    /// Writes still use full-word stores, so `dst` must have capacity for the untrimmed block.
    /// @param dst Destination buffer; must have at least `i + Sizes.B160` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @param e Fifth payload word.
    /// @param trim Number of bytes to trim from the end of the payload (0..31).
    /// @return next Byte offset immediately after the written block.
    function write160(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        bytes32 e,
        uint trim
    ) internal pure returns (uint next) {
        uint p;
        (next, p) = prepareWrite(dst, i, key, 160, trim, Sizes.B160);
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
    function writeHead32(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes memory tail
    ) internal pure returns (uint next) {
        uint p;
        (next, p) = prepareWrite(dst, i, key, 32 + tail.length, 0, Sizes.B32 + tail.length);
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
    function writeHead64(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes memory tail
    ) internal pure returns (uint next) {
        uint p;
        (next, p) = prepareWrite(dst, i, key, 64 + tail.length, 0, Sizes.B64 + tail.length);
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
            mcopy(add(p, 0x48), add(tail, 0x20), mload(tail))
        }
    }

    /// @notice Write a dynamic block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.Header + data.length` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param data Dynamic payload bytes.
    /// @return next Byte offset immediately after the written block.
    function write(bytes memory dst, uint i, bytes4 key, bytes memory data) internal pure returns (uint next) {
        uint p;
        (next, p) = prepareWrite(dst, i, key, data.length, 0, Sizes.Header + data.length);
        assembly ("memory-safe") {
            mcopy(add(p, 0x08), add(data, 0x20), mload(data))
        }
    }

    // -------------------------------------------------------------------------
    // Append helpers
    // -------------------------------------------------------------------------

    /// @notice Append arbitrary bytes to the writer.
    /// @param writer Destination writer; `i` is advanced by `data.length`.
    /// @param data Bytes to append.
    function append(Writer memory writer, bytes memory data) internal pure {
        uint next = writer.i + data.length;
        if (next > writer.dst.length) revert WriterOverflow();
        // Copy `data` into `dst` starting at the current write position.
        assembly ("memory-safe") {
            mcopy(add(add(mload(add(writer, 0x40)), 0x20), mload(writer)), add(data, 0x20), mload(data))
        }
        writer.i = next;
    }

    /// @notice Append a raw 32-byte word without a block header.
    /// @param writer Destination writer; `i` is advanced by `32 - trim`.
    /// @param value Word to append.
    /// @param trim Number of bytes to trim from the end of the word (0..31).
    function append32Raw(Writer memory writer, bytes32 value, uint trim) internal pure {
        writer.i = write32Raw(writer.dst, writer.i, value, trim);
    }

    /// @notice Append a fixed-width 32-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the trimmed logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param trim Number of bytes to trim from the end of the payload (0..31).
    function append32(Writer memory writer, bytes4 key, bytes32 a, uint trim) internal pure {
        writer.i = write32(writer.dst, writer.i, key, a, trim);
    }

    /// @notice Append a fixed-width 64-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the trimmed logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param trim Number of bytes to trim from the end of the payload (0..31).
    function append64(Writer memory writer, bytes4 key, bytes32 a, bytes32 b, uint trim) internal pure {
        writer.i = write64(writer.dst, writer.i, key, a, b, trim);
    }

    /// @notice Append a fixed-width 96-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the trimmed logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param trim Number of bytes to trim from the end of the payload (0..31).
    function append96(Writer memory writer, bytes4 key, bytes32 a, bytes32 b, bytes32 c, uint trim) internal pure {
        writer.i = write96(writer.dst, writer.i, key, a, b, c, trim);
    }

    /// @notice Append a fixed-width 128-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the trimmed logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @param trim Number of bytes to trim from the end of the payload (0..31).
    function append128(
        Writer memory writer,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        uint trim
    ) internal pure {
        writer.i = write128(writer.dst, writer.i, key, a, b, c, d, trim);
    }

    /// @notice Append a fixed-width 160-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the trimmed logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @param e Fifth payload word.
    /// @param trim Number of bytes to trim from the end of the payload (0..31).
    function append160(
        Writer memory writer,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        bytes32 e,
        uint trim
    ) internal pure {
        writer.i = write160(writer.dst, writer.i, key, a, b, c, d, e, trim);
    }

    /// @notice Append an ABI-style boolean as a 32-byte scalar payload block.
    /// Encodes `false` as `bytes32(0)` and `true` as `bytes32(uint(1))`.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B32`.
    /// @param key Block type key.
    /// @param value Boolean value to encode.
    function appendBool(Writer memory writer, bytes4 key, bool value) internal pure {
        writer.i = writeBool(writer.dst, writer.i, key, value);
    }

    /// @notice Append a dynamic block with a fixed 32-byte head word.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B32 + tail.length`.
    /// @param key Block type key.
    /// @param a Fixed head word.
    /// @param tail Dynamic payload bytes appended after the head.
    function appendHead32(Writer memory writer, bytes4 key, bytes32 a, bytes memory tail) internal pure {
        writer.i = writeHead32(writer.dst, writer.i, key, a, tail);
    }

    /// @notice Append a dynamic block with a fixed 64-byte head.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B64 + tail.length`.
    /// @param key Block type key.
    /// @param a First fixed head word.
    /// @param b Second fixed head word.
    /// @param tail Dynamic payload bytes appended after the head.
    function appendHead64(Writer memory writer, bytes4 key, bytes32 a, bytes32 b, bytes memory tail) internal pure {
        writer.i = writeHead64(writer.dst, writer.i, key, a, b, tail);
    }

    /// @notice Append a dynamic block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Header + data.length`.
    /// @param key Block type key.
    /// @param data Dynamic payload bytes.
    function appendBytes(Writer memory writer, bytes4 key, bytes memory data) internal pure {
        writer.i = write(writer.dst, writer.i, key, data);
    }

    /// @notice Append a BALANCE block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Amount`.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendBalance(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
        writer.i = write96(writer.dst, writer.i, Keys.Balance, asset, meta, bytes32(amount), 0);
    }

    /// @notice Append a BALANCE block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Balance`.
    /// @param value Balance fields to encode.
    function appendBalance(Writer memory writer, AssetAmount memory value) internal pure {
        writer.i = write96(writer.dst, writer.i, Keys.Balance, value.asset, value.meta, bytes32(value.amount), 0);
    }

    /// @notice Append a USER_POSITION block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B96`.
    /// @param account Account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    function appendUserPosition(Writer memory writer, bytes32 account, bytes32 asset, bytes32 meta) internal pure {
        writer.i = write96(writer.dst, writer.i, Keys.UserPosition, account, asset, meta, 0);
    }

    /// @notice Append a USER_POSITION block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B96`.
    /// @param value User-position fields to encode.
    function appendUserPosition(Writer memory writer, UserPosition memory value) internal pure {
        writer.i = write96(writer.dst, writer.i, Keys.UserPosition, value.account, value.asset, value.meta, 0);
    }

    /// @notice Append an AMOUNT block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Amount`.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendAmount(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
        writer.i = write96(writer.dst, writer.i, Keys.Amount, asset, meta, bytes32(amount), 0);
    }

    /// @notice Append an AMOUNT block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Balance`.
    /// @param value Amount fields to encode.
    function appendAmount(Writer memory writer, AssetAmount memory value) internal pure {
        writer.i = write96(writer.dst, writer.i, Keys.Amount, value.asset, value.meta, bytes32(value.amount), 0);
    }

    /// @notice Append a USER_AMOUNT block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B128`.
    /// @param account Account identifier.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendUserAmount(Writer memory writer, bytes32 account, bytes32 asset, bytes32 meta, uint amount) internal pure {
        writer.i = write128(writer.dst, writer.i, Keys.UserAmount, account, asset, meta, bytes32(amount), 0);
    }

    /// @notice Append a USER_AMOUNT block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B128`.
    /// @param value User-amount fields to encode.
    function appendUserAmount(Writer memory writer, UserAmount memory value) internal pure {
        writer.i = write128(
            writer.dst,
            writer.i,
            Keys.UserAmount,
            value.account,
            value.asset,
            value.meta,
            bytes32(value.amount),
            0
        );
    }

    /// @notice Append an ASSET block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B64`.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    function appendAsset(Writer memory writer, bytes32 asset, bytes32 meta) internal pure {
        writer.i = write64(writer.dst, writer.i, Keys.Asset, asset, meta, 0);
    }

    /// @notice Append a BALANCE block only if `amount > 0`; silently skips zero amounts.
    /// @param writer Destination writer.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount; block is not written if this is zero.
    function appendNonZeroBalance(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
        if (amount > 0) appendBalance(writer, asset, meta, amount);
    }

    /// @notice Append a BALANCE block from a struct only if the amount is non-zero.
    /// @param writer Destination writer.
    /// @param value Balance fields; block is not written if `value.amount == 0`.
    function appendNonZeroBalance(Writer memory writer, AssetAmount memory value) internal pure {
        if (value.amount > 0) appendBalance(writer, value);
    }

    /// @notice Append a BOUNTY block to the writer.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Bounty`.
    /// @param amount Relayer reward amount.
    /// @param relayer Relayer account identifier.
    function appendBounty(Writer memory writer, uint amount, bytes32 relayer) internal pure {
        writer.i = write64(writer.dst, writer.i, Keys.Bounty, bytes32(amount), relayer, 0);
    }

    /// @notice Append a HOST_ASSET_AMOUNT block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.HostAssetAmount`.
    /// @param host Host node ID.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendHostAssetAmount(
        Writer memory writer,
        uint host,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) internal pure {
        writer.i = write128(writer.dst, writer.i, Keys.HostAssetAmount, bytes32(host), asset, meta, bytes32(amount), 0);
    }

    /// @notice Append a HOST_ASSET_AMOUNT block from a host and asset amount.
    /// @param writer Destination writer; `i` is advanced by `Sizes.HostAssetAmount`.
    /// @param host Host node ID.
    /// @param value Host-asset-amount fields to encode.
    function appendHostAssetAmount(Writer memory writer, uint host, AssetAmount memory value) internal pure {
        writer.i = write128(
            writer.dst,
            writer.i,
            Keys.HostAssetAmount,
            bytes32(host),
            value.asset,
            value.meta,
            bytes32(value.amount),
            0
        );
    }

    /// @notice Append a TRANSACTION block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Transaction`.
    /// @param value Transfer record fields to encode.
    function appendTx(Writer memory writer, Tx memory value) internal pure {
        writer.i = write160(
            writer.dst,
            writer.i,
            Keys.Transaction,
            bytes32(value.from),
            bytes32(value.to),
            value.asset,
            value.meta,
            bytes32(value.amount),
            0
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
        if (writer.i > writer.dst.length) revert IncompleteWriter();
        out = writer.dst;
        // Overwrite the memory length word of `out` with the actual written length.
        assembly ("memory-safe") {
            mstore(out, mload(writer))
        }
    }
}
