// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Keys} from "./Keys.sol";
import {Buffers} from "./Buffers.sol";
import {Sizes, Specs} from "./Specs.sol";
import {max32} from "../utils/Utils.sol";

/// @title Blocks
/// @notice Stateless helpers for inspecting and encoding protocol blocks.
library Blocks {
    /// @dev A block header or declared payload exceeds the source region.
    error MalformedBlocks();
    /// @dev A block key or payload size does not match its expected shape.
    error InvalidBlock();
    /// @dev A write exceeded the destination buffer.
    error WriterOverflow();
    /// @dev A fixed-width write received an invalid final-word keep length.
    error InvalidKeep();

    // -------------------------------------------------------------------------
    // Calldata inspection and navigation
    // -------------------------------------------------------------------------

    /// @notice Read and validate a block header within a calldata region.
    function header(uint offset, uint end, uint i) internal pure returns (bytes4 key, uint len) {
        if (i + Sizes.Header > end) revert MalformedBlocks();
        uint abs = offset + i;
        key = bytes4(msg.data[abs:abs + 4]);
        len = uint32(bytes4(msg.data[abs + 4:abs + 8]));
        if (i + Sizes.Header + len > end) revert MalformedBlocks();
    }

    /// @notice Return whether `i` identifies a header with `key` in a calldata region.
    function hasAt(uint offset, uint len, uint i, bytes4 key) internal pure returns (bool) {
        if (i > len || Sizes.Header > len - i) return false;
        return bytes4(msg.data[offset + i:offset + i + 4]) == key;
    }

    /// @notice Validate a block and return its payload position and following position.
    function expect(
        uint offset,
        uint limit,
        uint i,
        bytes4 key,
        uint min,
        uint max
    ) internal pure returns (uint abs, uint next) {
        (bytes4 current, uint len) = header(offset, limit, i);
        if (current != key) revert InvalidBlock();
        if (len < min || (max != 0 && len > max)) revert InvalidBlock();
        abs = offset + i + Sizes.Header;
        next = i + Sizes.Header + len;
    }

    /// @notice Count consecutive blocks with `key` from `i`.
    function run(
        uint offset,
        uint end,
        uint i,
        bytes4 key
    ) internal pure returns (uint total, uint next) {
        next = i;
        while (next < end) {
            (bytes4 current, uint len) = header(offset, end, next);
            if (current != key) break;
            next += Sizes.Header + len;

            unchecked {
                ++total;
            }
        }
    }

    /// @notice Find the first block with `key` at or after `i`.
    function find(uint offset, uint end, uint i, bytes4 key) internal pure returns (uint) {
        while (i < end) {
            (bytes4 current, uint len) = header(offset, end, i);
            if (current == key) return i;
            i += Sizes.Header + len;
        }
        return end;
    }

    // -------------------------------------------------------------------------
    // Memory writes
    // -------------------------------------------------------------------------

    /// @dev Write a block header and return its memory pointer.
    function writeHeader(bytes memory dst, uint i, bytes4 key, uint32 len) private pure returns (uint p) {
        uint word = (uint(uint32(key)) << 224) | (uint(len) << 192);
        assembly ("memory-safe") {
            p := add(add(dst, 0x20), i)
            mstore(p, word)
        }
    }

    /// @notice Write a block with a dynamic payload at byte offset `i`.
    function write(bytes memory dst, uint i, bytes4 key, bytes memory payload) internal pure returns (uint next) {
        next = i + Sizes.Header + payload.length;
        if (next > dst.length) revert WriterOverflow();
        uint p = writeHeader(dst, i, key, uint32(max32(payload.length)));
        assembly ("memory-safe") {
            mcopy(add(p, 0x08), add(payload, 0x20), mload(payload))
        }
    }

    /// @notice Write a block with one payload word, keeping `keep` bytes from that word.
    function write32(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        uint keep
    ) internal pure returns (uint next) {
        if (keep == 0 || keep > 32) revert InvalidKeep();
        if (i + Sizes.B32 > dst.length) revert WriterOverflow();
        next = i + Sizes.Header + keep;
        uint p = writeHeader(dst, i, key, uint32(keep));
        assembly ("memory-safe") {
            mstore(add(p, 0x08), a)
        }
    }

    /// @notice Write a block with two payload words, keeping `keep` bytes from the final word.
    function write64(
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

    /// @notice Write a fixed-width BALANCE block at byte offset `i`.
    /// @return next Byte offset immediately after the encoded block.
    function writeBalance(
        bytes memory dst,
        uint i,
        bytes32 asset,
        uint amount
    ) internal pure returns (uint next) {
        next = i + Sizes.Balance;
        if (next > dst.length) revert WriterOverflow();

        uint spec = Specs.Balance;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), asset)
            mstore(add(p, 0x28), amount)
        }
    }

    /// @notice Write a block with three payload words, keeping `keep` bytes from the final word.
    function write96(
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

    /// @notice Write a block with four payload words, keeping `keep` bytes from the final word.
    function write128(
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

    /// @notice Write a fixed-width TRANSACTION block at byte offset `i`.
    /// @return next Byte offset immediately after the encoded block.
    function writeTransaction(
        bytes memory dst,
        uint i,
        bytes32 from,
        bytes32 to,
        bytes32 asset,
        uint amount
    ) internal pure returns (uint next) {
        next = i + Sizes.Transaction;
        if (next > dst.length) revert WriterOverflow();

        uint spec = Specs.Transaction;
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, spec)
            mstore(add(p, 0x08), from)
            mstore(add(p, 0x28), to)
            mstore(add(p, 0x48), asset)
            mstore(add(p, 0x68), amount)
        }
    }

    /// @notice Write a block with five payload words, keeping `keep` bytes from the final word.
    function write160(
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
    function write32BytesBytes(
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

    /// @notice Write a block with a 64-byte head and two nested BYTES payloads.
    function write64BytesBytes(
        bytes memory dst,
        uint i,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes memory c,
        bytes memory d
    ) internal pure returns (uint next) {
        uint cLen = c.length;
        uint len = 64 + 2 * Sizes.Header + cLen + d.length;
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
        {
            uint r = writeHeader(dst, i + Sizes.Header + 64 + Sizes.Header + cLen, Keys.Bytes, uint32(max32(d.length)));
            assembly ("memory-safe") {
                mcopy(add(r, 0x08), add(d, 0x20), mload(d))
            }
        }
    }

    /// @notice Write a block with a 64-byte head and one nested BYTES payload.
    function write64Bytes(
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

    // -------------------------------------------------------------------------
    // Block append helpers
    // -------------------------------------------------------------------------

    /// @notice Reserve and append a dynamic block.
    function append(
        uint meta,
        bytes memory dst,
        uint spec,
        bytes memory payload
    ) internal pure returns (uint updated, bytes memory out) {
        Specs.validate(spec, payload.length);
        return appendKey(meta, dst, Specs.key(spec), payload);
    }

    function appendKey(
        uint meta,
        bytes memory dst,
        bytes4 key,
        bytes memory payload
    ) private pure returns (uint updated, bytes memory out) {
        uint size = Sizes.Header + payload.length;
        uint i;
        (updated, out, i) = Buffers.reserve(meta, dst, size, size);
        write(out, i, key, payload);
    }

    /// @notice Reserve and append a fixed-width block with up to one payload word.
    function append32(
        uint meta,
        bytes memory dst,
        uint spec,
        bytes32 a
    ) internal pure returns (uint updated, bytes memory out) {
        uint keep = Specs.exact(spec, 1, 32);
        return append32Key(meta, dst, Specs.key(spec), a, keep);
    }

    function append32Key(
        uint meta,
        bytes memory dst,
        bytes4 key,
        bytes32 a,
        uint keep
    ) private pure returns (uint updated, bytes memory out) {
        uint i;
        (updated, out, i) = Buffers.reserve(meta, dst, Sizes.Header + keep, Sizes.B32);
        write32(out, i, key, a, keep);
    }

    /// @notice Reserve and append a fixed-width block with up to two payload words.
    function append64(
        uint meta,
        bytes memory dst,
        uint spec,
        bytes32 a,
        bytes32 b
    ) internal pure returns (uint updated, bytes memory out) {
        uint keep = Specs.exact(spec, 33, 64) - 32;
        return append64Key(meta, dst, Specs.key(spec), a, b, keep);
    }

    function append64Key(
        uint meta,
        bytes memory dst,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        uint keep
    ) private pure returns (uint updated, bytes memory out) {
        uint i;
        (updated, out, i) = Buffers.reserve(meta, dst, Sizes.Header + 32 + keep, Sizes.B64);
        write64(out, i, key, a, b, keep);
    }

    /// @notice Reserve and append a fixed-width block with up to three payload words.
    function append96(
        uint meta,
        bytes memory dst,
        uint spec,
        bytes32 a,
        bytes32 b,
        bytes32 c
    ) internal pure returns (uint updated, bytes memory out) {
        uint keep = Specs.exact(spec, 65, 96) - 64;
        return append96Key(meta, dst, Specs.key(spec), a, b, c, keep);
    }

    function append96Key(
        uint meta,
        bytes memory dst,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        uint keep
    ) private pure returns (uint updated, bytes memory out) {
        uint i;
        (updated, out, i) = Buffers.reserve(meta, dst, Sizes.Header + 64 + keep, Sizes.B96);
        write96(out, i, key, a, b, c, keep);
    }

    /// @notice Reserve and append a fixed-width block with up to four payload words.
    function append128(
        uint meta,
        bytes memory dst,
        uint spec,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d
    ) internal pure returns (uint updated, bytes memory out) {
        uint keep = Specs.exact(spec, 97, 128) - 96;
        return append128Key(meta, dst, Specs.key(spec), a, b, c, d, keep);
    }

    function append128Key(
        uint meta,
        bytes memory dst,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        uint keep
    ) private pure returns (uint updated, bytes memory out) {
        uint i;
        (updated, out, i) = Buffers.reserve(meta, dst, Sizes.Header + 96 + keep, Sizes.B128);
        write128(out, i, key, a, b, c, d, keep);
    }

    /// @notice Reserve and append a fixed-width block with up to five payload words.
    function append160(
        uint meta,
        bytes memory dst,
        uint spec,
        bytes32 a,
        bytes32 b,
        bytes32 c,
        bytes32 d,
        bytes32 e
    ) internal pure returns (uint updated, bytes memory out) {
        uint keep = Specs.exact(spec, 129, 160) - 128;
        uint i;
        (updated, out, i) = Buffers.reserve(meta, dst, Sizes.Header + 128 + keep, Sizes.B160);
        write160(out, i, Specs.key(spec), a, b, c, d, e, keep);
    }

    /// @notice Reserve and append a block with a 32-byte head and two nested BYTES payloads.
    function append32BytesBytes(
        uint meta,
        bytes memory dst,
        uint spec,
        bytes32 a,
        bytes memory b,
        bytes memory c
    ) internal pure returns (uint updated, bytes memory out) {
        Specs.validate(spec, 32 + 2 * Sizes.Header + b.length + c.length);
        return append32BytesBytesKey(meta, dst, Specs.key(spec), a, b, c);
    }

    function append32BytesBytesKey(
        uint meta,
        bytes memory dst,
        bytes4 key,
        bytes32 a,
        bytes memory b,
        bytes memory c
    ) private pure returns (uint updated, bytes memory out) {
        uint size = Sizes.B32 + 2 * Sizes.Header + b.length + c.length;
        uint i;
        (updated, out, i) = Buffers.reserve(meta, dst, size, size);
        write32BytesBytes(out, i, key, a, b, c);
    }

    /// @notice Reserve and append a block with a 64-byte head and two nested BYTES payloads.
    function append64BytesBytes(
        uint meta,
        bytes memory dst,
        uint spec,
        bytes32 a,
        bytes32 b,
        bytes memory c,
        bytes memory d
    ) internal pure returns (uint updated, bytes memory out) {
        Specs.validate(spec, 64 + 2 * Sizes.Header + c.length + d.length);
        return append64BytesBytesKey(meta, dst, Specs.key(spec), a, b, c, d);
    }

    function append64BytesBytesKey(
        uint meta,
        bytes memory dst,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes memory c,
        bytes memory d
    ) private pure returns (uint updated, bytes memory out) {
        uint size = Sizes.B64 + 2 * Sizes.Header + c.length + d.length;
        uint i;
        (updated, out, i) = Buffers.reserve(meta, dst, size, size);
        write64BytesBytes(out, i, key, a, b, c, d);
    }

    /// @notice Reserve and append a block with a 64-byte head and one nested BYTES payload.
    function append64Bytes(
        uint meta,
        bytes memory dst,
        uint spec,
        bytes32 a,
        bytes32 b,
        bytes memory c
    ) internal pure returns (uint updated, bytes memory out) {
        Specs.validate(spec, 64 + Sizes.Header + c.length);
        return append64BytesKey(meta, dst, Specs.key(spec), a, b, c);
    }

    function append64BytesKey(
        uint meta,
        bytes memory dst,
        bytes4 key,
        bytes32 a,
        bytes32 b,
        bytes memory c
    ) private pure returns (uint updated, bytes memory out) {
        uint size = Sizes.B64 + Sizes.Header + c.length;
        uint i;
        (updated, out, i) = Buffers.reserve(meta, dst, size, size);
        write64Bytes(out, i, key, a, b, c);
    }

    function appendBytes(
        uint meta,
        bytes memory dst,
        bytes memory value
    ) internal pure returns (uint updated, bytes memory out) {
        return appendKey(meta, dst, Keys.Bytes, value);
    }

    function appendString(
        uint meta,
        bytes memory dst,
        string memory value
    ) internal pure returns (uint updated, bytes memory out) {
        return appendKey(meta, dst, Keys.String, bytes(value));
    }

    function appendStep(
        uint meta,
        bytes memory dst,
        uint target,
        uint resources,
        bytes memory request
    ) internal pure returns (uint updated, bytes memory out) {
        return append64BytesKey(meta, dst, Keys.Step, bytes32(target), bytes32(resources), request);
    }

    function appendCall(
        uint meta,
        bytes memory dst,
        uint target,
        uint resources,
        bytes memory payload
    ) internal pure returns (uint updated, bytes memory out) {
        return append64BytesKey(meta, dst, Keys.Call, bytes32(target), bytes32(resources), payload);
    }

    function appendContext(
        uint meta,
        bytes memory dst,
        bytes32 account,
        bytes memory state,
        bytes memory request
    ) internal pure returns (uint updated, bytes memory out) {
        return append32BytesBytesKey(meta, dst, Keys.Context, account, state, request);
    }

    function appendStatus(
        uint meta,
        bytes memory dst,
        uint code
    ) internal pure returns (uint updated, bytes memory out) {
        return append32Key(meta, dst, Keys.Status, bytes32(code), 32);
    }

    function appendBalance(
        uint meta,
        bytes memory dst,
        bytes32 asset,
        uint amount
    ) internal pure returns (uint updated, bytes memory out) {
        uint i;
        (updated, out, i) = Buffers.reserve(meta, dst, Sizes.Balance, Sizes.B64);
        writeBalance(out, i, asset, amount);
    }

    function appendAmount(
        uint meta,
        bytes memory dst,
        bytes32 asset,
        uint amount
    ) internal pure returns (uint updated, bytes memory out) {
        return append64Key(meta, dst, Keys.Amount, asset, bytes32(amount), 32);
    }

    function appendAccountAmount(
        uint meta,
        bytes memory dst,
        bytes32 account,
        bytes32 asset,
        uint amount
    ) internal pure returns (uint updated, bytes memory out) {
        return append96Key(meta, dst, Keys.AccountAmount, account, asset, bytes32(amount), 32);
    }

    function appendAsset(
        uint meta,
        bytes memory dst,
        bytes32 asset
    ) internal pure returns (uint updated, bytes memory out) {
        return append32Key(meta, dst, Keys.Asset, asset, 32);
    }

    function appendBounty(
        uint meta,
        bytes memory dst,
        uint amount,
        bytes32 relayer
    ) internal pure returns (uint updated, bytes memory out) {
        return append64Key(meta, dst, Keys.Bounty, bytes32(amount), relayer, 32);
    }

    function appendCustody(
        uint meta,
        bytes memory dst,
        uint host,
        bytes32 asset,
        uint amount
    ) internal pure returns (uint updated, bytes memory out) {
        return append96Key(meta, dst, Keys.Custody, bytes32(host), asset, bytes32(amount), 32);
    }

    function appendTransaction(
        uint meta,
        bytes memory dst,
        bytes32 from,
        bytes32 to,
        bytes32 asset,
        uint amount
    ) internal pure returns (uint updated, bytes memory out) {
        uint i;
        (updated, out, i) = Buffers.reserve(meta, dst, Sizes.Transaction, Sizes.B128);
        writeTransaction(out, i, from, to, asset, amount);
    }

    // -------------------------------------------------------------------------
    // Block factory helpers
    // -------------------------------------------------------------------------

    /// @notice Encode a block with a raw payload.
    /// @param key Block type key.
    /// @param payload Raw payload bytes.
    /// @return Encoded block bytes.
    function create(bytes4 key, bytes memory payload) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(payload.length)), payload);
    }

    /// @notice Encode a block with a single 32-byte payload word.
    /// @param key Block type key.
    /// @param value 32-byte payload.
    /// @return Encoded block bytes.
    function create32(bytes4 key, bytes32 value) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x20)), value);
    }

    /// @notice Encode a block with two 32-byte payload words (64-byte payload).
    /// @param key Block type key.
    /// @param a First payload word.
    /// @param b Second payload word.
    /// @return Encoded block bytes.
    function create64(bytes4 key, bytes32 a, bytes32 b) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x40)), a, b);
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

    /// @notice Encode a BYTES block with a raw payload.
    /// @param value Raw payload bytes.
    /// @return Encoded BYTES block bytes.
    function data(bytes memory value) internal pure returns (bytes memory) {
        return create(Keys.Bytes, value);
    }

    /// @notice Encode a STRING block with a UTF-8 payload.
    /// @param value String payload.
    /// @return Encoded STRING block bytes.
    function text(string memory value) internal pure returns (bytes memory) {
        return create(Keys.String, bytes(value));
    }

    /// @notice Encode a BOUNTY block.
    /// @param amount Relayer reward amount.
    /// @param relayer Relayer account identifier.
    /// @return Encoded BOUNTY block bytes.
    function bounty(uint amount, bytes32 relayer) internal pure returns (bytes memory) {
        return create64(Keys.Bounty, bytes32(amount), relayer);
    }

    /// @notice Encode a BALANCE block.
    /// @param asset Asset identifier.
    /// @param amount Token amount.
    /// @return Encoded BALANCE block bytes.
    function balance(bytes32 asset, uint amount) internal pure returns (bytes memory) {
        return create64(Keys.Balance, asset, bytes32(amount));
    }

    /// @notice Encode a CUSTODY block.
    /// @param host Host node ID holding the custody.
    /// @param asset Asset identifier.
    /// @param amount Token amount.
    /// @return Encoded CUSTODY block bytes.
    function custody(uint host, bytes32 asset, uint amount) internal pure returns (bytes memory) {
        return create96(Keys.Custody, bytes32(host), asset, bytes32(amount));
    }

    /// @notice Encode a TRANSACTION block.
    /// @param from Source account identifier.
    /// @param to Destination account identifier.
    /// @param asset Asset identifier.
    /// @param amount Transfer amount.
    /// @return Encoded TRANSACTION block bytes.
    function transaction(bytes32 from, bytes32 to, bytes32 asset, uint amount) internal pure returns (bytes memory) {
        return create128(Keys.Transaction, from, to, asset, bytes32(amount));
    }

    /// @notice Encode a STEP block.
    /// @param target Command target identifier.
    /// @param resources Packed resources assigned to the step.
    /// @param request Raw nested request payload.
    /// @return Encoded STEP block bytes.
    function step(uint target, uint resources, bytes memory request) internal pure returns (bytes memory) {
        return create(Keys.Step, bytes.concat(bytes32(target), bytes32(resources), data(request)));
    }

    /// @notice Encode a CALL block.
    /// @param target Target node identifier.
    /// @param resources Packed resources assigned to the call.
    /// @param payload Raw calldata payload for the target.
    /// @return Encoded CALL block bytes.
    function call(uint target, uint resources, bytes memory payload) internal pure returns (bytes memory) {
        return create(Keys.Call, bytes.concat(bytes32(target), bytes32(resources), data(payload)));
    }

    /// @notice Encode a CONTEXT block.
    /// @param account Command account identifier.
    /// @param state Embedded state block stream.
    /// @param request Embedded request block stream.
    /// @return Encoded CONTEXT block bytes.
    function context(bytes32 account, bytes memory state, bytes memory request) internal pure returns (bytes memory) {
        return create(Keys.Context, bytes.concat(account, data(state), data(request)));
    }

    /// @notice Encode a RELAY block.
    /// @param portal Destination portal identifier, often the destination host ID.
    /// @param resources Chain-specific resources for the destination context.
    /// @param request Nested request block stream.
    /// @return Encoded RELAY block bytes.
    function relay(uint portal, uint resources, bytes memory request) internal pure returns (bytes memory) {
        return create(Keys.Relay, bytes.concat(bytes32(portal), bytes32(resources), data(request)));
    }

    /// @notice Encode a DISPATCH block.
    /// @param portal Destination portal identifier, often the destination host ID.
    /// @param resources Chain-specific resources for the destination dispatch.
    /// @param payload Encoded payload.
    /// @return Encoded DISPATCH block bytes.
    function dispatch(uint portal, uint resources, bytes memory payload) internal pure returns (bytes memory) {
        return create(Keys.Dispatch, bytes.concat(bytes32(portal), bytes32(resources), data(payload)));
    }
}
