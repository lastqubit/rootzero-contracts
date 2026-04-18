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

    /// @notice Allocate a writer sized for exactly `count` BALANCE blocks (1:1 ratio).
    /// @param count Number of balance blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocBalances(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, Sizes.Balance);
    }

    /// @notice Allocate a writer sized for exactly `count` AMOUNT blocks (1:1 ratio).
    /// @param count Number of amount blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocAmounts(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, Sizes.Amount);
    }

    /// @notice Allocate a writer sized for `2 * count` BALANCE blocks (2:1 ratio).
    /// Used when each input produces a paired output (e.g. input balance + output balance).
    /// @param count Number of input blocks; output capacity is doubled.
    /// @return writer Allocated writer.
    function allocPairedBalances(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE * 2, Sizes.Balance);
    }

    /// @notice Allocate a writer sized for `2 * count` AMOUNT blocks (2:1 ratio).
    /// Used when each input produces a paired output.
    /// @param count Number of input blocks; output capacity is doubled.
    /// @return writer Allocated writer.
    function allocPairedAmounts(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE * 2, Sizes.Amount);
    }

    /// @notice Allocate a writer for BALANCE blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units
    ///        (e.g. `ALLOC_SCALE` = 1:1, `2 * ALLOC_SCALE` = 2:1).
    /// @return writer Allocated writer.
    function allocScaledBalances(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, scaledRatio, Sizes.Balance);
    }

    /// @notice Allocate a writer for AMOUNT blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier expressed in `ALLOC_SCALE` units
    ///        (e.g. `ALLOC_SCALE` = 1:1, `2 * ALLOC_SCALE` = 2:1).
    /// @return writer Allocated writer.
    function allocScaledAmounts(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, scaledRatio, Sizes.Amount);
    }

    /// @notice Allocate a writer sized for exactly `count` TRANSACTION blocks (1:1 ratio).
    /// @param count Number of transaction blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocTxs(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, Sizes.Transaction);
    }

    /// @notice Allocate a writer sized for exactly `count` CUSTODY blocks (1:1 ratio).
    /// @param count Number of custody blocks to allocate space for.
    /// @return writer Allocated writer.
    function allocCustodies(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, Sizes.Custody);
    }

    /// @notice Allocate a writer for CUSTODY blocks with a custom output-to-input ratio.
    /// @param count Number of input blocks.
    /// @param scaledRatio Output count multiplier in `ALLOC_SCALE` units.
    /// @return writer Allocated writer.
    function allocScaledCustodies(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, scaledRatio, Sizes.Custody);
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
    // Low-level write helpers (direct index into a bytes buffer)
    // -------------------------------------------------------------------------

    /// @notice Write a BALANCE block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.Amount` bytes.
    /// @param i Write offset within `dst`.
    /// @param value Balance fields to encode.
    /// @return next Byte offset immediately after the written block.
    function writeBalanceBlock(bytes memory dst, uint i, AssetAmount memory value) internal pure returns (uint next) {
        next = i + Sizes.Amount;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(Keys.Balance, 96);
        // Write 8-byte header then three 32-byte payload words.
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x08), mload(value))
            mstore(add(p, 0x28), mload(add(value, 0x20)))
            mstore(add(p, 0x48), mload(add(value, 0x40)))
        }
    }

    /// @notice Write an AMOUNT block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.Balance` bytes.
    /// @param i Write offset within `dst`.
    /// @param value Amount fields to encode.
    /// @return next Byte offset immediately after the written block.
    function writeAmountBlock(bytes memory dst, uint i, AssetAmount memory value) internal pure returns (uint next) {
        next = i + Sizes.Balance;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(Keys.Amount, 96);
        // Write 8-byte header then three 32-byte payload words.
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x08), mload(value))
            mstore(add(p, 0x28), mload(add(value, 0x20)))
            mstore(add(p, 0x48), mload(add(value, 0x40)))
        }
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

    /// @notice Write a BOUNTY block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.Bounty` bytes.
    /// @param i Write offset within `dst`.
    /// @param amount Relayer reward amount.
    /// @param relayer Relayer account identifier.
    /// @return next Byte offset immediately after the written block.
    function writeBountyBlock(bytes memory dst, uint i, uint amount, bytes32 relayer) internal pure returns (uint next) {
        next = i + Sizes.Bounty;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(Keys.Bounty, 64);
        // Write 8-byte header then amount and relayer.
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x08), amount)
            mstore(add(p, 0x28), relayer)
        }
    }

    /// @notice Append a BOUNTY block to the writer.
    /// @param writer Destination writer; `i` is advanced by `Sizes.Bounty`.
    /// @param amount Relayer reward amount.
    /// @param relayer Relayer account identifier.
    function appendBounty(Writer memory writer, uint amount, bytes32 relayer) internal pure {
        writer.i = writeBountyBlock(writer.dst, writer.i, amount, relayer);
    }

    /// @notice Write a CUSTODY block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.Custody` bytes.
    /// @param i Write offset within `dst`.
    /// @param value Custody fields to encode.
    /// @return next Byte offset immediately after the written block.
    function writeCustodyBlock(bytes memory dst, uint i, HostAmount memory value) internal pure returns (uint next) {
        next = i + Sizes.Custody;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(Keys.Custody, 128);
        // Write 8-byte header then four 32-byte payload words.
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x08), mload(value))
            mstore(add(p, 0x28), mload(add(value, 0x20)))
            mstore(add(p, 0x48), mload(add(value, 0x40)))
            mstore(add(p, 0x68), mload(add(value, 0x60)))
        }
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

    /// @notice Write a TRANSACTION block directly into `dst` at byte offset `i`.
    /// @param dst Destination buffer; must have at least `i + Sizes.Transaction` bytes.
    /// @param i Write offset within `dst`.
    /// @param value Transfer record fields to encode.
    /// @return next Byte offset immediately after the written block.
    function writeTxBlock(bytes memory dst, uint i, Tx memory value) internal pure returns (uint next) {
        next = i + Sizes.Transaction;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(Keys.Transaction, 160);
        // Write 8-byte header then five 32-byte payload words.
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x08), mload(value))
            mstore(add(p, 0x28), mload(add(value, 0x20)))
            mstore(add(p, 0x48), mload(add(value, 0x40)))
            mstore(add(p, 0x68), mload(add(value, 0x60)))
            mstore(add(p, 0x88), mload(add(value, 0x80)))
        }
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
