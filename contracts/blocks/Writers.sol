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
    /// @dev Whether append helpers may expand the backing buffer when more capacity is needed.
    bool growable;
    /// @dev Destination buffer. Physical capacity may be padded up to a full 32-byte word;
    ///      final length is set to `i` by `finish`.
    bytes dst;
}

/// @title Hints
/// @notice Initial per-block capacity estimates for growable writers.
library Hints {
    uint constant Any = 128;
    uint constant Bytes = 128;
    uint constant Step = 256;
    uint constant Call = 256;
    uint constant Context = 512;
}

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
        writer = Writer({i: 0, end: len, growable: false, dst: new bytes(padded)});
    }

    /// @notice Allocate a growable writer with an initial logical byte capacity.
    /// @param hint Initial logical byte capacity to allocate.
    /// @return writer Freshly allocated growable writer positioned at index 0.
    function dynamic(uint hint) internal pure returns (Writer memory writer) {
        writer = alloc(hint);
        writer.growable = true;
    }

    /// @notice Core allocation routine used by all counted `alloc*` helpers.
    /// Computes `count * blockLen` and allocates that many bytes.
    /// @param count Number of output blocks.
    /// @param blockLen Logical byte size of each output block (including 8-byte header).
    /// @return writer Allocated writer.
    function allocFromCount(uint count, uint blockLen) internal pure returns (Writer memory writer) {
        if (count == 0) revert EmptyRequest();
        writer = alloc(count * blockLen);
    }

    /// @notice Core allocation routine used by counted growable `alloc*` helpers.
    /// Computes `count * hint` and allocates an expandable writer with that initial capacity.
    /// @param count Number of output blocks.
    /// @param hint Initial logical byte capacity per output block.
    /// @return writer Allocated growable writer.
    function allocFromHint(uint count, uint hint) internal pure returns (Writer memory writer) {
        if (count == 0) revert EmptyRequest();
        writer = dynamic(count * hint);
    }

    /// @notice Allocate a writer sized for exactly `count` dynamic blocks with a shared payload length.
    /// Each block reserves `Sizes.Header + payloadLen` bytes.
    /// @param count Number of blocks to allocate space for.
    /// @param payloadLen Payload byte length for each block.
    /// @return writer Allocated writer.
    function allocBytes(uint count, uint payloadLen) internal pure returns (Writer memory writer) {
        return allocFromCount(count, Sizes.Header + payloadLen);
    }

    /// @notice Allocate a writer for `count` variable-sized blocks using a per-block capacity hint.
    /// @dev The backing buffer expands automatically if encoded blocks exceed the initial hint.
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated growable writer.
    function allocAny(uint count) internal pure returns (Writer memory writer) {
        return allocFromHint(count, Hints.Any);
    }

    /// @notice Allocate a writer for `count` BYTES blocks using a per-block capacity hint.
    /// @dev The backing buffer expands automatically if encoded bytes blocks exceed the initial hint.
    /// @param count Number of bytes blocks to allocate space for.
    /// @return writer Allocated growable writer.
    function allocBytes(uint count) internal pure returns (Writer memory writer) {
        return allocFromHint(count, Hints.Bytes);
    }

    /// @notice Allocate a writer sized for exactly `count` 32-byte-payload blocks.
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated writer.
    function alloc32s(uint count) internal pure returns (Writer memory writer) {
        return allocFromCount(count, Sizes.B32);
    }

    /// @notice Allocate a writer sized for exactly `count` 64-byte-payload blocks.
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated writer.
    function alloc64s(uint count) internal pure returns (Writer memory writer) {
        return allocFromCount(count, Sizes.B64);
    }

    /// @notice Allocate a writer sized for exactly `count` 96-byte-payload blocks.
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated writer.
    function alloc96s(uint count) internal pure returns (Writer memory writer) {
        return allocFromCount(count, Sizes.B96);
    }

    /// @notice Allocate a writer sized for exactly `count` 128-byte-payload blocks.
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated writer.
    function alloc128s(uint count) internal pure returns (Writer memory writer) {
        return allocFromCount(count, Sizes.B128);
    }

    /// @notice Allocate a writer sized for exactly `count` 160-byte-payload blocks.
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated writer.
    function alloc160s(uint count) internal pure returns (Writer memory writer) {
        return allocFromCount(count, Sizes.B160);
    }

    /// @notice Allocate a writer sized for exactly `count` STATUS form blocks.
    /// @param count Number of blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocStatuses(uint count) internal pure returns (Writer memory writer) {
        return allocFromCount(count, Sizes.Status);
    }

    /// @notice Allocate a writer sized for exactly `count` ASSET blocks.
    /// @param count Number of asset blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocAssets(uint count) internal pure returns (Writer memory writer) {
        return alloc64s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` AMOUNT blocks.
    /// @param count Number of amount blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocAmounts(uint count) internal pure returns (Writer memory writer) {
        return alloc96s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` BALANCE blocks.
    /// @param count Number of balance blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocBalances(uint count) internal pure returns (Writer memory writer) {
        return alloc96s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` ACCOUNT_AMOUNT form blocks.
    /// @param count Number of account amount blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocAccountAmounts(uint count) internal pure returns (Writer memory writer) {
        return alloc128s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` CUSTODY blocks.
    /// @param count Number of custody blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocCustodies(uint count) internal pure returns (Writer memory writer) {
        return alloc128s(count);
    }

    /// @notice Allocate a writer sized for exactly `count` TRANSACTION blocks.
    /// @param count Number of transaction blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocTransactions(uint count) internal pure returns (Writer memory writer) {
        return alloc160s(count);
    }

    /// @notice Allocate a writer for `count` STEP blocks using a per-block capacity hint.
    /// @dev The backing buffer expands automatically if encoded steps exceed the initial hint.
    /// @param count Number of step blocks to allocate space for.
    /// @return writer Allocated growable writer.
    function allocSteps(uint count) internal pure returns (Writer memory writer) {
        return allocFromHint(count, Hints.Step);
    }

    /// @notice Allocate a writer for `count` CALL blocks using a per-block capacity hint.
    /// @dev The backing buffer expands automatically if encoded calls exceed the initial hint.
    /// @param count Number of call blocks to allocate space for.
    /// @return writer Allocated growable writer.
    function allocCalls(uint count) internal pure returns (Writer memory writer) {
        return allocFromHint(count, Hints.Call);
    }

    /// @notice Allocate a writer for `count` CONTEXT blocks using a per-block capacity hint.
    /// @dev The backing buffer expands automatically if encoded contexts exceed the initial hint.
    /// @param count Number of context blocks to allocate space for.
    /// @return writer Allocated growable writer.
    function allocContexts(uint count) internal pure returns (Writer memory writer) {
        return allocFromHint(count, Hints.Context);
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

    /// @notice Write a block with a 32-byte head and two nested BYTES payloads.
    /// @param dst Destination buffer; must have at least `i + Sizes.B32 + 2 * Sizes.Header + b.length + c.length` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block key.
    /// @param a Fixed head word.
    /// @param b First raw nested payload.
    /// @param c Second raw nested payload.
    /// @return next Byte offset immediately after the written block.
    function writeBlock32BytesBytes(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes memory b,
        bytes memory c
    ) internal pure returns (uint next) {
        uint bLen = b.length;
        uint len = 32 + 2 * Sizes.Header + bLen + c.length;
        next = i + Sizes.Header + len;
        if (next > dst.length) revert WriterOverflow();

        {
            uint p = writeHeader(dst, i, key, uint32(max32(len)));
            assembly ("memory-safe") {
                mstore(add(p, 0x08), a)
            }
        }

        {
            uint q = writeHeader(dst, i + Sizes.Header + 32, Keys.Bytes, uint32(max32(bLen)));
            assembly ("memory-safe") {
                mcopy(add(q, 0x08), add(b, 0x20), mload(b))
            }
        }

        {
            uint r = writeHeader(dst, i + Sizes.Header + 32 + Sizes.Header + bLen, Keys.Bytes, uint32(max32(c.length)));
            assembly ("memory-safe") {
                mcopy(add(r, 0x08), add(c, 0x20), mload(c))
            }
        }
    }

    /// @notice Write a block with a 64-byte head and nested BYTES payload.
    /// @param dst Destination buffer; must have at least `i + Sizes.B64 + Sizes.Header + c.length` bytes.
    /// @param i Write offset within `dst`.
    /// @param key Block key.
    /// @param a First head word.
    /// @param b Second head word.
    /// @param c Raw nested payload.
    /// @return next Byte offset immediately after the written block.
    function writeBlock64Bytes(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes memory c
    ) internal pure returns (uint next) {
        uint cLen = c.length;
        uint len = 64 + Sizes.Header + cLen;
        next = i + Sizes.Header + len;
        if (next > dst.length) revert WriterOverflow();

        {
            uint p = writeHeader(dst, i, key, uint32(max32(len)));
            assembly ("memory-safe") {
                mstore(add(p, 0x08), a)
                mstore(add(p, 0x28), b)
            }
        }

        {
            uint q = writeHeader(dst, i + Sizes.Header + 64, Keys.Bytes, uint32(max32(cLen)));
            assembly ("memory-safe") {
                mcopy(add(q, 0x08), add(c, 0x20), mload(c))
            }
        }
    }

    /// @notice Reserve physical write space and advance the logical writer position.
    /// Fixed writers may use padded backing space but cannot advance past logical capacity;
    /// growable writers expand when `touch` exceeds current capacity.
    /// @return i Original write offset.
    function reserve(Writer memory writer, uint next, uint touch) private pure returns (uint i) {
        i = writer.i;
        if (touch > writer.dst.length) {
            if (!writer.growable) revert WriterOverflow();
        }

        if (touch > writer.end && writer.growable) {
            uint end = writer.end == 0 ? 64 : writer.end * 2;
            while (end < touch) {
                end *= 2;
            }

            uint padded = ((end + 31) & ~uint(31)) + 32;
            bytes memory src = writer.dst;
            bytes memory dst = new bytes(padded);
            assembly ("memory-safe") {
                mcopy(add(dst, 0x20), add(src, 0x20), i)
            }
            writer.end = end;
            writer.dst = dst;
        }

        if (next > writer.end) revert WriterOverflow();
        writer.i = next;
    }

    // -------------------------------------------------------------------------
    // Append helpers
    // -------------------------------------------------------------------------

    /// @notice Append arbitrary bytes to the writer.
    /// @param writer Destination writer; `i` is advanced by `data.length`.
    /// @param data Bytes to append.
    function append(Writer memory writer, bytes memory data) internal pure {
        uint next = writer.i + data.length;
        uint i = reserve(writer, next, next);
        write(writer.dst, i, data);
    }

    /// @notice Append a raw 32-byte word without a block header.
    /// @param writer Destination writer; `i` is advanced by `keep`.
    /// @param value Word to append.
    /// @param keep Number of bytes to keep from the word (1..32).
    function append32(Writer memory writer, bytes32 value, uint keep) internal pure {
        uint i = writer.i;
        uint next = i + keep;
        i = reserve(writer, next, i + 32);
        write32(writer.dst, i, value, keep);
    }

    /// @notice Append two raw 32-byte words without a block header.
    /// @param writer Destination writer; `i` is advanced by `32 + keep`.
    /// @param a First word to append.
    /// @param b Second word to append.
    /// @param keep Number of bytes to keep from the final word (1..32).
    function append64(Writer memory writer, bytes32 a, bytes32 b, uint keep) internal pure {
        uint i = writer.i;
        uint next = i + 32 + keep;
        i = reserve(writer, next, i + 64);
        write64(writer.dst, i, a, b, keep);
    }

    /// @notice Append three raw 32-byte words without a block header.
    /// @param writer Destination writer; `i` is advanced by `64 + keep`.
    /// @param a First word to append.
    /// @param b Second word to append.
    /// @param c Third word to append.
    /// @param keep Number of bytes to keep from the final word (1..32).
    function append96(Writer memory writer, bytes32 a, bytes32 b, bytes32 c, uint keep) internal pure {
        uint i = writer.i;
        uint next = i + 64 + keep;
        i = reserve(writer, next, i + 96);
        write96(writer.dst, i, a, b, c, keep);
    }

    /// @notice Append a dynamic block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Header + data.length`.
    /// @param key Block type key.
    /// @param data Dynamic payload bytes.
    function appendBlock(Writer memory writer, bytes4 key, bytes memory data) internal pure {
        uint next = writer.i + Sizes.Header + data.length;
        uint i = reserve(writer, next, next);
        writeBlock(writer.dst, i, key, data);
    }

    /// @notice Append a fixed-width 32-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the kept logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function appendBlock32(Writer memory writer, bytes4 key, bytes32 a, uint keep) internal pure {
        uint i = writer.i;
        uint next = i + Sizes.Header + keep;
        i = reserve(writer, next, i + Sizes.B32);
        writeBlock32(writer.dst, i, key, a, keep);
    }

    /// @notice Append a fixed-width 64-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the kept logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function appendBlock64(Writer memory writer, bytes4 key, bytes32 a, bytes32 b, uint keep) internal pure {
        uint i = writer.i;
        uint next = i + Sizes.Header + 32 + keep;
        i = reserve(writer, next, i + Sizes.B64);
        writeBlock64(writer.dst, i, key, a, b, keep);
    }

    /// @notice Append a fixed-width 96-byte-payload block.
    /// @param writer Destination writer; `i` is advanced by the kept logical block length.
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @param c Third payload word.
    /// @param keep Number of bytes to keep from the final payload word (1..32).
    function appendBlock96(Writer memory writer, bytes4 key, bytes32 a, bytes32 b, bytes32 c, uint keep) internal pure {
        uint i = writer.i;
        uint next = i + Sizes.Header + 64 + keep;
        i = reserve(writer, next, i + Sizes.B96);
        writeBlock96(writer.dst, i, key, a, b, c, keep);
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
        uint i = writer.i;
        uint next = i + Sizes.Header + 96 + keep;
        i = reserve(writer, next, i + Sizes.B128);
        writeBlock128(writer.dst, i, key, a, b, c, d, keep);
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
        uint i = writer.i;
        uint next = i + Sizes.Header + 128 + keep;
        i = reserve(writer, next, i + Sizes.B160);
        writeBlock160(writer.dst, i, key, a, b, c, d, e, keep);
    }

    /// @notice Append a block with a 32-byte head and two nested BYTES payloads.
    /// @param writer Destination writer; `i` is advanced by the encoded block length.
    /// @param key Block key.
    /// @param a Fixed head word.
    /// @param b First raw nested payload.
    /// @param c Second raw nested payload.
    function appendBlock32BytesBytes(
        Writer memory writer,
        bytes4 key,
        bytes32 a,
        bytes memory b,
        bytes memory c
    ) internal pure {
        uint i = writer.i;
        uint next = i + Sizes.B32 + 2 * Sizes.Header + b.length + c.length;
        i = reserve(writer, next, next);
        writeBlock32BytesBytes(writer.dst, i, key, a, b, c);
    }

    /// @notice Append a block with a 64-byte head and nested BYTES payload.
    /// @param writer Destination writer; `i` is advanced by the encoded block length.
    /// @param key Block key.
    /// @param a First head word.
    /// @param b Second head word.
    /// @param c Raw nested payload.
    function appendBlock64Bytes(Writer memory writer, bytes4 key, bytes32 a, bytes32 b, bytes memory c) internal pure {
        uint i = writer.i;
        uint next = i + Sizes.B64 + Sizes.Header + c.length;
        i = reserve(writer, next, next);
        writeBlock64Bytes(writer.dst, i, key, a, b, c);
    }

    /// @notice Append a BYTES block.
    /// @param writer Destination writer; `i` is advanced by the encoded BYTES block length.
    /// @param data Raw bytes payload.
    function appendBytes(Writer memory writer, bytes memory data) internal pure {
        appendBlock(writer, Keys.Bytes, data);
    }

    /// @notice Append a STEP block with a nested request BYTES payload.
    /// @param writer Destination writer; `i` is advanced by the encoded STEP block length.
    /// @param target Command target identifier.
    /// @param value Native value forwarded with the step.
    /// @param request Raw nested request payload.
    function appendStep(Writer memory writer, uint target, uint value, bytes memory request) internal pure {
        appendBlock64Bytes(writer, Keys.Step, bytes32(target), bytes32(value), request);
    }

    /// @notice Append a CALL block with a nested payload BYTES block.
    /// @param writer Destination writer; `i` is advanced by the encoded CALL block length.
    /// @param target Call target identifier.
    /// @param value Native value forwarded with the call.
    /// @param data Raw nested call payload.
    function appendCall(Writer memory writer, uint target, uint value, bytes memory data) internal pure {
        appendBlock64Bytes(writer, Keys.Call, bytes32(target), bytes32(value), data);
    }

    /// @notice Append a CONTEXT block with nested state and request BYTES payloads.
    /// @param writer Destination writer; `i` is advanced by the encoded CONTEXT block length.
    /// @param account Command account identifier.
    /// @param state Raw nested state payload.
    /// @param request Raw nested request payload.
    function appendContext(
        Writer memory writer,
        bytes32 account,
        bytes memory state,
        bytes memory request
    ) internal pure {
        appendBlock32BytesBytes(writer, Keys.Context, account, state, request);
    }

    /// @notice Append a STATUS form block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Status`.
    /// @param ok Status value to encode.
    function appendStatus(Writer memory writer, bool ok) internal pure {
        appendBlock32(writer, Keys.Status, ok ? bytes32(uint(1) << 248) : bytes32(0), 1);
    }

    /// @notice Append a BALANCE block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Amount`.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendBalance(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
        appendBlock96(writer, Keys.Balance, asset, meta, bytes32(amount), 32);
    }

    /// @notice Append a BALANCE block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Balance`.
    /// @param value Balance fields to encode.
    function appendBalance(Writer memory writer, AssetAmount memory value) internal pure {
        appendBalance(writer, value.asset, value.meta, value.amount);
    }

    /// @notice Append an AMOUNT block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Amount`.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendAmount(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
        appendBlock96(writer, Keys.Amount, asset, meta, bytes32(amount), 32);
    }

    /// @notice Append an AMOUNT block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Balance`.
    /// @param value Amount fields to encode.
    function appendAmount(Writer memory writer, AssetAmount memory value) internal pure {
        appendAmount(writer, value.asset, value.meta, value.amount);
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
        appendBlock128(writer, Keys.AccountAmount, account, asset, meta, bytes32(amount), 32);
    }

    /// @notice Append an ACCOUNT_AMOUNT form block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B128`.
    /// @param value Account amount fields to encode.
    function appendAccountAmount(Writer memory writer, AccountAmount memory value) internal pure {
        appendAccountAmount(writer, value.account, value.asset, value.meta, value.amount);
    }

    /// @notice Append an ASSET block.
    /// @param writer Destination writer; `i` is advanced by `Sizes.B64`.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    function appendAsset(Writer memory writer, bytes32 asset, bytes32 meta) internal pure {
        appendBlock64(writer, Keys.Asset, asset, meta, 32);
    }

    /// @notice Append a BOUNTY block to the writer.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Bounty`.
    /// @param amount Relayer reward amount.
    /// @param relayer Relayer account identifier.
    function appendBounty(Writer memory writer, uint amount, bytes32 relayer) internal pure {
        appendBlock64(writer, Keys.Bounty, bytes32(amount), relayer, 32);
    }

    /// @notice Append a CUSTODY block using separate field values.
    /// @param writer Destination writer; `i` is advanced by `Sizes.HostAmount`.
    /// @param host Host node ID.
    /// @param asset Asset identifier.
    /// @param meta Asset metadata slot.
    /// @param amount Token amount.
    function appendCustody(Writer memory writer, uint host, bytes32 asset, bytes32 meta, uint amount) internal pure {
        appendBlock128(writer, Keys.Custody, bytes32(host), asset, meta, bytes32(amount), 32);
    }

    /// @notice Append a CUSTODY block from a host and asset amount.
    /// @param writer Destination writer; `i` is advanced by `Sizes.HostAmount`.
    /// @param host Host node ID.
    /// @param value Custody fields to encode.
    function appendCustody(Writer memory writer, uint host, AssetAmount memory value) internal pure {
        appendCustody(writer, host, value.asset, value.meta, value.amount);
    }

    /// @notice Append a CUSTODY block from a host amount struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.HostAmount`.
    /// @param value Custody fields to encode.
    function appendCustody(Writer memory writer, HostAmount memory value) internal pure {
        appendCustody(writer, value.host, value.asset, value.meta, value.amount);
    }

    /// @notice Append a TRANSACTION block from a struct.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Transaction`.
    /// @param value Transfer record fields to encode.
    function appendTransaction(Writer memory writer, Tx memory value) internal pure {
        appendBlock160(
            writer,
            Keys.Transaction,
            bytes32(value.from),
            bytes32(value.to),
            value.asset,
            value.meta,
            bytes32(value.amount),
            32
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
