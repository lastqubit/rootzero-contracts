// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { AssetAmount, HostAmount, Tx, Keys, Sizes } from "./Schema.sol";

/// @notice Sequential block stream writer backed by a pre-allocated memory buffer.
struct Writer {
    /// @dev Current write position: number of bytes written so far.
    uint i;
    /// @dev Allocated buffer capacity in bytes.
    uint end;
    /// @dev Destination buffer; final length is set to `i` by `finish`.
    bytes dst;
}

// Fixed-point scaling denominator for output-count allocation.
// A `scaledRatio` of `ALLOC_SCALE` means 1:1 (one output block per input block).
// `2 * ALLOC_SCALE` means 2:1; non-integer ratios revert with `BadWriterRatio`.
uint constant ALLOC_SCALE = 10_000;

/// @title Writers
/// @notice Response block stream builder for the rootzero protocol.
/// Allocates a fixed-size memory buffer up front and writes binary-encoded
/// blocks into it sequentially. Call `finish` to trim the buffer to the
/// number of bytes actually written and return the result.
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

    // -------------------------------------------------------------------------
    // Header encoding
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

    // -------------------------------------------------------------------------
    // Allocation
    // -------------------------------------------------------------------------

    /// @notice Allocate a writer with an exact byte capacity.
    /// @param len Number of bytes to pre-allocate.
    /// @return writer Freshly allocated writer positioned at index 0.
    function alloc(uint len) internal pure returns (Writer memory writer) {
        writer = Writer({i: 0, end: len, dst: new bytes(len)});
    }

    /// @notice Allocate a writer sized for exactly `count` BALANCE blocks (1:1 ratio).
    /// @param count Number of balance blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocBalances(uint count) internal pure returns (Writer memory writer) {
        return alloc96s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` AMOUNT blocks (1:1 ratio).
    /// @param count Number of amount blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocAmounts(uint count) internal pure returns (Writer memory writer) {
        return alloc96s(count);
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

    /// @notice Allocate a writer for AMOUNT blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units
    ///        (e.g. `ALLOC_SCALE` = 1:1, `2 * ALLOC_SCALE` = 2:1).
    /// @return writer Allocated writer.
    function allocScaledAmounts(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocScaled96s(count, scaledRatio);
    }

    /// @notice Allocate a writer for dynamic blocks with a shared payload length and custom output ratio.
    /// Each block reserves `Sizes.Header + payloadLen` bytes.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units.
    /// @param payloadLen Payload byte length for each block.
    /// @return writer Allocated writer.
    function allocScaledBytes(uint count, uint scaledRatio, uint payloadLen) internal pure returns (Writer memory writer) {
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

    /// @notice Allocate a writer sized for exactly `count` CUSTODY blocks (1:1 ratio).
    /// @param count Number of custody blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocCustodies(uint count) internal pure returns (Writer memory writer) {
        return alloc128s(count);
    }

    /// @notice Allocate a writer for CUSTODY blocks with a custom output-to-input ratio.
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
    /// @param blockLen Byte size of each output block (including 8-byte header).
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
        writer = Writer({i: 0, end: len, dst: new bytes(len)});
    }

    // -------------------------------------------------------------------------
    // Fixed-width write helpers
    // -------------------------------------------------------------------------

    /// @notice Write a fixed-width 32-byte-payload block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.B32` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @return next Byte offset immediately after the written block.
    function write32(bytes memory dst, uint i, bytes4 key, bytes32 a) internal pure returns (uint next) {
        next = i + Sizes.B32;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(key, 32);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x08), a)
        }
    }

    /// @notice Write a fixed-width 64-byte-payload block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.B64` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @return next Byte offset immediately after the written block.
    function write64(bytes memory dst, uint i, bytes4 key, bytes32 a, bytes32 b) internal pure returns (uint next) {
        next = i + Sizes.B64;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(key, 64);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
        }
    }

    /// @notice Write a fixed-width 96-byte-payload block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.B96` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @return next Byte offset immediately after the written block.
    function write96(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c
    ) internal pure returns (uint next) {
        next = i + Sizes.B96;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(key, 96);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
            mstore(add(p, 0x48), c)
        }
    }

    /// @notice Write a fixed-width 128-byte-payload block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.B128` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @return next Byte offset immediately after the written block.
    function write128(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d
    ) internal pure returns (uint next) {
        next = i + Sizes.B128;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(key, 128);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x08), a)
            mstore(add(p, 0x28), b)
            mstore(add(p, 0x48), c)
            mstore(add(p, 0x68), d)
        }
    }

    /// @notice Write a fixed-width 160-byte-payload block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.B160` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @param e Fifth payload word.
    /// @return next Byte offset immediately after the written block.
    function write160(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        bytes32 e
    ) internal pure returns (uint next) {
        next = i + Sizes.B160;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(key, 160);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
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
        next = i + Sizes.B32 + tail.length;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(key, 32 + tail.length);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
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
        next = i + Sizes.B64 + tail.length;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(key, 64 + tail.length);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
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
        next = i + Sizes.Header + data.length;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(key, data.length);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mcopy(add(p, 0x08), add(data, 0x20), mload(data))
        }
    }

    // -------------------------------------------------------------------------
    // Typed write helpers
    // -------------------------------------------------------------------------

    /// @notice Write a BALANCE block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.Amount` bytes.
    /// @param i Write offset within `dst`.
    /// @param value Balance fields to encode.
    /// @return next Byte offset immediately after the written block.
    function writeBalanceBlock(bytes memory dst, uint i, AssetAmount memory value) internal pure returns (uint next) {
        return write96(dst, i, Keys.Balance, value.asset, value.meta, bytes32(value.amount));
    }

    /// @notice Write an AMOUNT block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.Balance` bytes.
    /// @param i Write offset within `dst`.
    /// @param value Amount fields to encode.
    /// @return next Byte offset immediately after the written block.
    function writeAmountBlock(bytes memory dst, uint i, AssetAmount memory value) internal pure returns (uint next) {
        return write96(dst, i, Keys.Amount, value.asset, value.meta, bytes32(value.amount));
    }

    /// @notice Write a BOUNTY block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.Bounty` bytes.
    /// @param i Write offset within `dst`.
    /// @param amount Relayer reward amount.
    /// @param relayer Relayer account identifier.
    /// @return next Byte offset immediately after the written block.
    function writeBountyBlock(bytes memory dst, uint i, uint amount, bytes32 relayer) internal pure returns (uint next) {
        return write64(dst, i, Keys.Bounty, bytes32(amount), relayer);
    }

    /// @notice Write a CUSTODY block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.Custody` bytes.
    /// @param i Write offset within `dst`.
    /// @param value Custody fields to encode.
    /// @return next Byte offset immediately after the written block.
    function writeCustodyBlock(bytes memory dst, uint i, HostAmount memory value) internal pure returns (uint next) {
        return write128(dst, i, Keys.Custody, bytes32(value.host), value.asset, value.meta, bytes32(value.amount));
    }

    /// @notice Write a TRANSACTION block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.Transaction` bytes.
    /// @param i Write offset within `dst`.
    /// @param value Transfer record fields to encode.
    /// @return next Byte offset immediately after the written block.
    function writeTxBlock(bytes memory dst, uint i, Tx memory value) internal pure returns (uint next) {
        return write160(
            dst,
            i,
            Keys.Transaction,
            bytes32(value.from),
            bytes32(value.to),
            value.asset,
            value.meta,
            bytes32(value.amount)
        );
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

    /// @notice Append a fixed-width 32-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B32`.
    /// @param key Block type key.
    /// @param a First payload word.
    function append32(Writer memory writer, bytes4 key, bytes32 a) internal pure {
        writer.i = write32(writer.dst, writer.i, key, a);
    }

    /// @notice Append a fixed-width 64-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B64`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    function append64(Writer memory writer, bytes4 key, bytes32 a, bytes32 b) internal pure {
        writer.i = write64(writer.dst, writer.i, key, a, b);
    }

    /// @notice Append a fixed-width 96-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B96`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    function append96(Writer memory writer, bytes4 key, bytes32 a, bytes32 b, bytes32 c) internal pure {
        writer.i = write96(writer.dst, writer.i, key, a, b, c);
    }

    /// @notice Append a fixed-width 128-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B128`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    function append128(Writer memory writer, bytes4 key, bytes32 a, bytes32 b, bytes32 c, bytes32 d) internal pure {
        writer.i = write128(writer.dst, writer.i, key, a, b, c, d);
    }

    /// @notice Append a fixed-width 160-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B160`.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param d Fourth payload word.
    /// @param e Fifth payload word.
    function append160(
        Writer memory writer,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        bytes32 e
    ) internal pure {
        writer.i = write160(writer.dst, writer.i, key, a, b, c, d, e);
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
        appendBalance(writer, AssetAmount(asset, meta, amount));
    }

    /// @notice Append a BALANCE block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Balance`.
    /// @param value Balance fields to encode.
    function appendBalance(Writer memory writer, AssetAmount memory value) internal pure {
        writer.i = writeBalanceBlock(writer.dst, writer.i, value);
    }

    /// @notice Append an AMOUNT block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Amount`.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendAmount(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
        appendAmount(writer, AssetAmount(asset, meta, amount));
    }

    /// @notice Append an AMOUNT block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Balance`.
    /// @param value Amount fields to encode.
    function appendAmount(Writer memory writer, AssetAmount memory value) internal pure {
        writer.i = writeAmountBlock(writer.dst, writer.i, value);
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
        writer.i = writeBountyBlock(writer.dst, writer.i, amount, relayer);
    }

    /// @notice Append a CUSTODY block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Custody`.
    /// @param host Host node ID.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendCustody(Writer memory writer, uint host, bytes32 asset, bytes32 meta, uint amount) internal pure {
        appendCustody(writer, HostAmount(host, asset, meta, amount));
    }

    /// @notice Append a CUSTODY block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Custody`.
    /// @param value Custody fields to encode.
    function appendCustody(Writer memory writer, HostAmount memory value) internal pure {
        writer.i = writeCustodyBlock(writer.dst, writer.i, value);
    }

    /// @notice Append a TRANSACTION block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Transaction`.
    /// @param value Transfer record fields to encode.
    function appendTx(Writer memory writer, Tx memory value) internal pure {
        writer.i = writeTxBlock(writer.dst, writer.i, value);
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
