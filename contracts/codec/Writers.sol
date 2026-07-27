// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AssetAmount, AccountAmount, HostAmount, Tx} from "../core/Types.sol";
import {Blocks} from "./Blocks.sol";
import {Buffers} from "./Buffers.sol";
import {Sizes, Specs} from "./Specs.sol";

/// @notice Sequential block stream writer backed by a pre-allocated memory buffer.
struct Writer {
    /// @dev Packed writer metadata: `[reserved:23][growable:1][end:4][i:4]`.
    uint packed;
    /// @dev Destination buffer. Physical capacity may be padded up to a full 32-byte word;
    /// final length is set to the packed write position by `finish`.
    bytes dst;
}

/// @title Writers
/// @notice Response block stream builder for the rootzero protocol.
/// Initializes logical capacity from raw metadata or a block specification,
/// then lazily allocates and writes binary-encoded blocks sequentially.
/// Physical allocation is rounded up to whole 32-byte words for scratch space,
/// while `Writer.end` tracks logical capacity. Call `finish` to trim the buffer.
library Writers {
    /// @dev `finish` called with a writer whose `i` exceeds `dst.length`.
    error IncompleteWriter();

    // -------------------------------------------------------------------------
    // Initialization helpers
    // -------------------------------------------------------------------------

    /// @notice Initialize writer metadata without allocating a backing buffer.
    /// @param len Initial logical byte capacity of the writer.
    /// @param growable Whether append helpers may expand the capacity.
    /// @return writer Unallocated writer positioned at index 0.
    function init(uint len, bool growable) internal pure returns (Writer memory writer) {
        writer.packed = Buffers.init(len, growable);
    }

    /// @notice Initialize writer metadata for `count` blocks described by `spec`.
    /// @param spec Packed block key, payload bounds, allocation hint, and flags.
    /// @param count Number of blocks the writer is expected to encode.
    /// @return writer Unallocated writer with capacity derived from the specification,
    /// or an inert empty writer when `count` is zero.
    function init(uint spec, uint count) internal pure returns (Writer memory writer) {
        if (count == 0) return writer;

        uint size = Sizes.Header + Specs.hint(spec);
        bool growable = Specs.growable(spec);
        writer = init(count * size, growable);
    }

    // -------------------------------------------------------------------------
    // Writer state
    // -------------------------------------------------------------------------

    /// @dev Reserve through a `Writer` and update it in place.
    function reserve(Writer memory writer, uint advance, uint touch) private pure returns (uint i) {
        (writer.packed, writer.dst, i) = Buffers.reserve(writer.packed, writer.dst, advance, touch);
    }

    // -------------------------------------------------------------------------
    // Append helpers
    // -------------------------------------------------------------------------

    /// @notice Append arbitrary bytes to the writer.
    /// @param writer Destination writer; `i` is advanced by `data.length`.
    /// @param data Bytes to append.
    function append(Writer memory writer, bytes memory data) internal pure {
        uint i = reserve(writer, data.length, data.length);
        Buffers.write(writer.dst, i, data);
    }

    /// @notice Append a raw 32-byte word without a block header.
    /// @param writer Destination writer; `i` is advanced by `keep`.
    /// @param value Word to append.
    /// @param keep Number of bytes to keep from the word (1..32).
    function append32(Writer memory writer, bytes32 value, uint keep) internal pure {
        uint i = reserve(writer, keep, 32);
        Buffers.write32(writer.dst, i, value);
    }

    /// @notice Append two raw 32-byte words without a block header.
    /// @param writer Destination writer; `i` is advanced by `32 + keep`.
    /// @param a First word to append.
    /// @param b Second word to append.
    /// @param keep Number of bytes to keep from the final word (1..32).
    function append64(Writer memory writer, bytes32 a, bytes32 b, uint keep) internal pure {
        uint i = reserve(writer, 32 + keep, 64);
        Buffers.write64(writer.dst, i, a, b);
    }

    /// @notice Append three raw 32-byte words without a block header.
    /// @param writer Destination writer; `i` is advanced by `64 + keep`.
    /// @param a First word to append.
    /// @param b Second word to append.
    /// @param c Third word to append.
    /// @param keep Number of bytes to keep from the final word (1..32).
    function append96(Writer memory writer, bytes32 a, bytes32 b, bytes32 c, uint keep) internal pure {
        uint i = reserve(writer, 64 + keep, 96);
        Buffers.write96(writer.dst, i, a, b, c);
    }

    /// @notice Append a dynamic protocol block.
    function appendBlock(Writer memory writer, uint spec, bytes memory data) internal pure {
        (writer.packed, writer.dst) = Blocks.append(writer.packed, writer.dst, spec, data);
    }

    function appendBlock32(Writer memory writer, uint spec, bytes32 a) internal pure {
        (writer.packed, writer.dst) = Blocks.append32(writer.packed, writer.dst, spec, a);
    }

    function appendBlock64(Writer memory writer, uint spec, bytes32 a, bytes32 b) internal pure {
        (writer.packed, writer.dst) = Blocks.append64(writer.packed, writer.dst, spec, a, b);
    }

    function appendBlock96(Writer memory writer, uint spec, bytes32 a, bytes32 b, bytes32 c) internal pure {
        (writer.packed, writer.dst) = Blocks.append96(writer.packed, writer.dst, spec, a, b, c);
    }

    function appendBlock128(
        Writer memory writer,
        uint spec,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d
    ) internal pure {
        (writer.packed, writer.dst) = Blocks.append128(writer.packed, writer.dst, spec, a, b, c, d);
    }

    function appendBlock160(
        Writer memory writer,
        uint spec,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        bytes32 e
    ) internal pure {
        (writer.packed, writer.dst) = Blocks.append160(writer.packed, writer.dst, spec, a, b, c, d, e);
    }

    function appendBlock32BytesBytes(
        Writer memory writer,
        uint spec,
        bytes32 a,
        bytes memory b,
        bytes memory c
    ) internal pure {
        (writer.packed, writer.dst) = Blocks.append32BytesBytes(writer.packed, writer.dst, spec, a, b, c);
    }

    function appendBlock64BytesBytes(
        Writer memory writer,
        uint spec,
        bytes32 a,
        bytes32 b,
        bytes memory c,
        bytes memory d
    ) internal pure {
        (writer.packed, writer.dst) = Blocks.append64BytesBytes(writer.packed, writer.dst, spec, a, b, c, d);
    }

    function appendBlock64Bytes(
        Writer memory writer,
        uint spec,
        bytes32 a,
        bytes32 b,
        bytes memory c
    ) internal pure {
        (writer.packed, writer.dst) = Blocks.append64Bytes(writer.packed, writer.dst, spec, a, b, c);
    }

    function appendBytes(Writer memory writer, bytes memory data) internal pure {
        (writer.packed, writer.dst) = Blocks.appendBytes(writer.packed, writer.dst, data);
    }

    function appendString(Writer memory writer, string memory data) internal pure {
        (writer.packed, writer.dst) = Blocks.appendString(writer.packed, writer.dst, data);
    }

    function appendStep(Writer memory writer, uint target, uint resources, bytes memory request) internal pure {
        (writer.packed, writer.dst) = Blocks.appendStep(writer.packed, writer.dst, target, resources, request);
    }

    function appendCall(Writer memory writer, uint target, uint resources, bytes memory data) internal pure {
        (writer.packed, writer.dst) = Blocks.appendCall(writer.packed, writer.dst, target, resources, data);
    }

    function appendContext(Writer memory writer, bytes32 account, bytes memory state, bytes memory request) internal pure {
        (writer.packed, writer.dst) = Blocks.appendContext(writer.packed, writer.dst, account, state, request);
    }

    function appendStatus(Writer memory writer, uint code) internal pure {
        (writer.packed, writer.dst) = Blocks.appendStatus(writer.packed, writer.dst, code);
    }

    function appendBalance(Writer memory writer, bytes32 asset, uint amount) internal pure {
        (writer.packed, writer.dst) = Blocks.appendBalance(writer.packed, writer.dst, asset, amount);
    }

    function appendBalance(Writer memory writer, AssetAmount memory value) internal pure {
        appendBalance(writer, value.asset, value.amount);
    }

    function appendAmount(Writer memory writer, bytes32 asset, uint amount) internal pure {
        (writer.packed, writer.dst) = Blocks.appendAmount(writer.packed, writer.dst, asset, amount);
    }

    function appendAmount(Writer memory writer, AssetAmount memory value) internal pure {
        appendAmount(writer, value.asset, value.amount);
    }

    function appendAccountAmount(
        Writer memory writer,
        bytes32 account,
        bytes32 asset,
        uint amount
    ) internal pure {
        (writer.packed, writer.dst) = Blocks.appendAccountAmount(writer.packed, writer.dst, account, asset, amount);
    }

    function appendAccountAmount(Writer memory writer, AccountAmount memory value) internal pure {
        appendAccountAmount(writer, value.account, value.asset, value.amount);
    }

    function appendAsset(Writer memory writer, bytes32 asset) internal pure {
        (writer.packed, writer.dst) = Blocks.appendAsset(writer.packed, writer.dst, asset);
    }

    function appendBounty(Writer memory writer, uint amount, bytes32 relayer) internal pure {
        (writer.packed, writer.dst) = Blocks.appendBounty(writer.packed, writer.dst, amount, relayer);
    }

    function appendCustody(Writer memory writer, uint host, bytes32 asset, uint amount) internal pure {
        (writer.packed, writer.dst) = Blocks.appendCustody(writer.packed, writer.dst, host, asset, amount);
    }

    function appendCustody(Writer memory writer, uint host, AssetAmount memory value) internal pure {
        appendCustody(writer, host, value.asset, value.amount);
    }

    function appendCustody(Writer memory writer, HostAmount memory value) internal pure {
        appendCustody(writer, value.host, value.asset, value.amount);
    }

    function appendTransaction(
        Writer memory writer,
        bytes32 from,
        bytes32 to,
        bytes32 asset,
        uint amount
    ) internal pure {
        (writer.packed, writer.dst) = Blocks.appendTransaction(writer.packed, writer.dst, from, to, asset, amount);
    }

    function appendTransaction(Writer memory writer, Tx memory value) internal pure {
        appendTransaction(writer, value.from, value.to, value.asset, value.amount);
    }

    // -------------------------------------------------------------------------
    // Finalisation
    // -------------------------------------------------------------------------

    /// @notice Return an empty buffer when unused, otherwise trim `dst` to the bytes written.
    /// Sets the `bytes` length slot in memory to the packed write position without copying.
    /// @param writer Completed writer.
    /// @return out The written block stream; length equals the packed write position.
    function finish(Writer memory writer) internal pure returns (bytes memory out) {
        (uint i, uint end, ) = Buffers.decode(writer.packed);
        if (i == 0) return new bytes(0);
        if (i > end || i > writer.dst.length) revert IncompleteWriter();
        out = Buffers.trim(writer.dst, i);
    }
}
