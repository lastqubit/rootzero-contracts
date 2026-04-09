// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Cur, Cursors } from "./Cursors.sol";
import { AssetAmount, HostAmount, Tx, Keys } from "./Schema.sol";

struct Writer {
    uint i;
    uint end;
    bytes dst;
}

uint constant ALLOC_SCALE = 10_000;
uint constant BALANCE_BLOCK_LEN = 104;
uint constant BOUNTY_BLOCK_LEN = 72;
uint constant CUSTODY_BLOCK_LEN = 136;
uint constant TX_BLOCK_LEN = 168;

library Writers2 {
    function alloc(Cur memory cur) internal pure returns (Writer memory writer) {
        if (cur.i > cur.len) revert Cursors.MalformedBlocks();
        writer = Writer({i: 0, end: cur.len - cur.i, dst: new bytes(cur.len - cur.i)});
    }

    function allocBalances(Cur memory cur) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(cur, ALLOC_SCALE, BALANCE_BLOCK_LEN);
    }

    function allocPairedBalances(Cur memory cur) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(cur, ALLOC_SCALE * 2, BALANCE_BLOCK_LEN);
    }

    function allocScaledBalances(Cur memory cur, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(cur, scaledRatio, BALANCE_BLOCK_LEN);
    }

    function allocTxs(Cur memory cur) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(cur, ALLOC_SCALE, TX_BLOCK_LEN);
    }

    function allocCustodies(Cur memory cur) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(cur, ALLOC_SCALE, CUSTODY_BLOCK_LEN);
    }

    function allocScaledCustodies(Cur memory cur, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(cur, scaledRatio, CUSTODY_BLOCK_LEN);
    }

    function allocFromScaledCount(
        Cur memory cur,
        uint scaledRatio,
        uint blockLen
    ) internal pure returns (Writer memory writer) {
        bytes4 key = cur.len < 4 ? bytes4(0) : bytes4(msg.data[cur.offset:cur.offset + 4]);
        if (key == 0) revert Writers.EmptyRequest();
        cur.i = 0;
        (uint count, ) = Cursors.countRun(cur, key);
        writer = Writers.allocFromScaledCount(count, scaledRatio, blockLen);
    }
}

library Writers {
    error WriterOverflow();
    error IncompleteWriter();
    error EmptyRequest();

    // Encodes an 8-byte block header (4-byte key + 4-byte payloadLen) into a
    // uint so assembly can write the full header in one mstore while the
    // payload starts at offset + 8.
    function toBlockHeader(bytes4 key, uint len) internal pure returns (uint) {
        if (len > type(uint32).max) revert Cursors.MalformedBlocks();
        return (uint(uint32(key)) << 224) | (uint(uint32(len)) << 192);
    }

    function alloc(uint len) internal pure returns (Writer memory writer) {
        writer = Writer({i: 0, end: len, dst: new bytes(len)});
    }

    function append(Writer memory writer, bytes memory data) internal pure {
        uint next = writer.i + data.length;
        if (next > writer.dst.length) revert WriterOverflow();
        assembly ("memory-safe") {
            mcopy(add(add(mload(add(writer, 0x40)), 0x20), mload(writer)), add(data, 0x20), mload(data))
        }
        writer.i = next;
    }

    function allocBalances(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, BALANCE_BLOCK_LEN);
    }

    function allocPairedBalances(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE * 2, BALANCE_BLOCK_LEN);
    }

    function allocScaledBalances(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, scaledRatio, BALANCE_BLOCK_LEN);
    }

    function allocTxs(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, TX_BLOCK_LEN);
    }

    function allocCustodies(uint count) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, ALLOC_SCALE, CUSTODY_BLOCK_LEN);
    }

    function allocScaledCustodies(uint count, uint scaledRatio) internal pure returns (Writer memory writer) {
        return allocFromScaledCount(count, scaledRatio, CUSTODY_BLOCK_LEN);
    }

    function allocFromScaledCount(
        uint count,
        uint scaledRatio,
        uint blockLen
    ) internal pure returns (Writer memory writer) {
        if (count == 0) revert EmptyRequest();
        uint scaledCount = count * scaledRatio;
        if (scaledCount % ALLOC_SCALE != 0) revert Cursors.MalformedBlocks();
        uint len = (scaledCount / ALLOC_SCALE) * blockLen;
        writer = Writer({i: 0, end: len, dst: new bytes(len)});
    }

    function writeBalanceBlock(bytes memory dst, uint i, AssetAmount memory value) internal pure returns (uint next) {
        next = i + BALANCE_BLOCK_LEN;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(Keys.Balance, 96);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x08), mload(value))
            mstore(add(p, 0x28), mload(add(value, 0x20)))
            mstore(add(p, 0x48), mload(add(value, 0x40)))
        }
    }

    function appendBalance(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
        appendBalance(writer, AssetAmount(asset, meta, amount));
    }

    function appendBalance(Writer memory writer, AssetAmount memory value) internal pure {
        writer.i = writeBalanceBlock(writer.dst, writer.i, value);
    }

    function appendNonZeroBalance(Writer memory writer, bytes32 asset, bytes32 meta, uint amount) internal pure {
        if (amount > 0) appendBalance(writer, asset, meta, amount);
    }

    function appendNonZeroBalance(Writer memory writer, AssetAmount memory value) internal pure {
        if (value.amount > 0) appendBalance(writer, value);
    }

    function writeBountyBlock(bytes memory dst, uint i, uint amount, bytes32 relayer) internal pure returns (uint next) {
        next = i + BOUNTY_BLOCK_LEN;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(Keys.Bounty, 64);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x08), amount)
            mstore(add(p, 0x28), relayer)
        }
    }

    function appendBounty(Writer memory writer, uint amount, bytes32 relayer) internal pure {
        writer.i = writeBountyBlock(writer.dst, writer.i, amount, relayer);
    }

    function writeCustodyBlock(bytes memory dst, uint i, HostAmount memory value) internal pure returns (uint next) {
        next = i + CUSTODY_BLOCK_LEN;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(Keys.Custody, 128);
        assembly ("memory-safe") {
            let p := add(add(dst, 0x20), i)
            mstore(p, header)
            mstore(add(p, 0x08), mload(value))
            mstore(add(p, 0x28), mload(add(value, 0x20)))
            mstore(add(p, 0x48), mload(add(value, 0x40)))
            mstore(add(p, 0x68), mload(add(value, 0x60)))
        }
    }

    function appendCustody(Writer memory writer, uint host, bytes32 asset, bytes32 meta, uint amount) internal pure {
        appendCustody(writer, HostAmount(host, asset, meta, amount));
    }

    function appendCustody(Writer memory writer, HostAmount memory value) internal pure {
        writer.i = writeCustodyBlock(writer.dst, writer.i, value);
    }

    function writeTxBlock(bytes memory dst, uint i, Tx memory value) internal pure returns (uint next) {
        next = i + TX_BLOCK_LEN;
        if (next > dst.length) revert WriterOverflow();
        uint header = toBlockHeader(Keys.Transaction, 160);
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

    function appendTx(Writer memory writer, Tx memory value) internal pure {
        writer.i = writeTxBlock(writer.dst, writer.i, value);
    }

    function finish(Writer memory writer) internal pure returns (bytes memory out) {
        if (writer.i == 0) revert EmptyRequest();
        if (writer.i > writer.dst.length) revert IncompleteWriter();
        out = writer.dst;
        assembly ("memory-safe") {
            mstore(out, mload(writer))
        }
    }
}




