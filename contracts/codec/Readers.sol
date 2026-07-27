// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Sizes, Specs} from "./Specs.sol";
import {Keys} from "./Keys.sol";

/// @notice Mutable reader over a block stream stored in memory.
/// All positions (`i`) are byte offsets relative to the start of `source`.
struct Reader {
    /// @dev Current read position, relative to the source start.
    uint i;
    /// @dev Memory bytes containing the complete source region.
    bytes source;
}

using Readers for Reader;

/// @title Readers
/// @notice Memory block stream parser for the rootzero protocol.
/// A `Reader` advances through an existing `bytes memory` source without copying its contents.
/// Blocks are encoded as `[bytes4 key][bytes4 payloadLen][payload]`.
library Readers {
    /// @dev The current block has a truncated header or payload, an unexpected key,
    ///      or a payload size outside the accepted range.
    error InvalidBlock();

    /// @notice Create a reader backed by a memory byte array.
    /// @param source Memory bytes containing the block stream.
    /// @return cur Reader positioned at the beginning of `source`.
    function open(bytes memory source) internal pure returns (Reader memory cur) {
        cur.source = source;
    }

    /// @notice Return whether the reader has consumed its entire source.
    /// @param cur Reader whose position should be checked.
    /// @return Whether `cur.i` equals the source length.
    function done(Reader memory cur) internal pure returns (bool) {
        return cur.i == cur.source.length;
    }

    /// @notice Return whether the reader has bytes left to consume.
    /// @param cur Reader whose position should be checked.
    /// @return Whether `cur.i` differs from the source length.
    function more(Reader memory cur) internal pure returns (bool) {
        return cur.i != cur.source.length;
    }

    /// @notice Validate and consume the current block, advancing `cur.i` past it.
    /// @param cur Reader to advance.
    /// @param key Expected block key.
    /// @param min Minimum payload length.
    /// @param max Maximum payload length; zero means unbounded.
    /// @return abs Absolute memory address of the payload start.
    function consume(
        Reader memory cur,
        bytes4 key,
        uint min,
        uint max
    ) private pure returns (uint abs) {
        bytes memory source = cur.source;
        uint i = cur.i;

        if (i > source.length || source.length - i < Sizes.Header) revert InvalidBlock();

        bytes4 current;
        uint len;
        assembly ("memory-safe") {
            let header := mload(add(add(source, 0x20), i))
            current := header
            len := and(shr(192, header), 0xffffffff)
            abs := add(add(source, 0x28), i)
        }

        if (current != key || len < min || (max != 0 && len > max)) revert InvalidBlock();
        if (len > source.length - i - Sizes.Header) revert InvalidBlock();
        cur.i = i + Sizes.Header + len;
    }

    /// @notice Validate and consume the current block described by `spec`.
    function consume(Reader memory cur, uint spec) internal pure returns (uint abs) {
        return consume(cur, Specs.key(spec), Specs.min(spec), Specs.max(spec));
    }

    /// @notice Consume a BALANCE block and return its fields.
    /// @param cur Reader; advanced past the block.
    /// @return asset Asset identifier.
    /// @return amount Token amount.
    function unpackBalance(Reader memory cur) internal pure returns (bytes32 asset, uint amount) {
        uint abs = consume(cur, Keys.Balance, 64, 64);
        assembly ("memory-safe") {
            asset := mload(abs)
            amount := mload(add(abs, 0x20))
        }
    }

    /// @notice Consume a TRANSACTION block and return its fields.
    /// @param cur Reader; advanced past the block.
    /// @return from Source account identifier.
    /// @return to Destination account identifier.
    /// @return asset Asset identifier.
    /// @return amount Token amount.
    function unpackTransaction(
        Reader memory cur
    ) internal pure returns (bytes32 from, bytes32 to, bytes32 asset, uint amount) {
        uint abs = consume(cur, Keys.Transaction, 128, 128);
        assembly ("memory-safe") {
            from := mload(abs)
            to := mload(add(abs, 0x20))
            asset := mload(add(abs, 0x40))
            amount := mload(add(abs, 0x60))
        }
    }
}
