// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { HostAmount, Tx } from "../blocks/Schema.sol";
import { Cursor, Writer } from "../Cursors.sol";
import { MemRef } from "../blocks/Mem.sol";
import { Cursors, Keys } from "../blocks/Cursors.sol";
import { Mem } from "../blocks/Mem.sol";
import { Writers, BALANCE_BLOCK_LEN, CUSTODY_BLOCK_LEN, TX_BLOCK_LEN } from "../blocks/Writers.sol";

using Writers for Writer;
using Mem for MemRef;
using Cursors for Cursor;

contract TestBlockHelper {
    function testBlockHeader(bytes4 key, uint len) external pure returns (uint) {
        return Writers.toBlockHeader(key, len);
    }

    function testWriteBalanceBlock(bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(BALANCE_BLOCK_LEN);
        w.appendBalance(asset, meta, amount);
        return w.dst;
    }

    function testWriteTwoBalanceBlocks(
        bytes32 a1,
        bytes32 m1,
        uint v1,
        bytes32 a2,
        bytes32 m2,
        uint v2
    ) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(BALANCE_BLOCK_LEN * 2);
        w.appendBalance(a1, m1, v1);
        w.appendBalance(a2, m2, v2);
        return w.dst;
    }

    function testWriteCustodyBlock(
        uint host_,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(CUSTODY_BLOCK_LEN);
        w.appendCustody(host_, asset, meta, amount);
        return w.dst;
    }

    function testWriteTxBlock(
        bytes32 from_,
        bytes32 to_,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(TX_BLOCK_LEN);
        w.appendTx(Tx({ from: from_, to: to_, asset: asset, meta: meta, amount: amount }));
        return w.dst;
    }

    function testWriterDone() external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(BALANCE_BLOCK_LEN);
        return Writers.done(w);
    }

    function testWriterFinish(bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(BALANCE_BLOCK_LEN * 2);
        w.appendBalance(asset, meta, amount);
        return Writers.finish(w);
    }

    function testUnpackBalance(bytes calldata source, uint i)
        external
        pure
        returns (bytes32 asset, bytes32 meta, uint amount)
    {
        Cursor memory input = Cursors.openFrom(source, i);
        return input.unpackBalance();
    }

    function testToTxValue(bytes calldata source, uint i)
        external
        pure
        returns (bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount)
    {
        Cursor memory input = Cursors.openFrom(source, i);
        Tx memory value = input.unpackTxValue();
        return (value.from, value.to, value.asset, value.meta, value.amount);
    }

    function testCountBlocks(bytes calldata source, uint i, bytes4 key) external pure returns (uint count, uint cursor) {
        return Cursors.count(source, i, key);
    }

    function testCursorFrom(bytes calldata source, uint i)
        external
        pure
        returns (uint start, uint end, uint cursor)
    {
        uint base;
        assembly ("memory-safe") {
            base := source.offset
        }
        Cursor memory cur = Cursors.openFrom(source, i);
        return (cur.i - base, cur.end - base, cur.next);
    }

    function testCursorFromN(bytes calldata source, uint i, uint n)
        external
        pure
        returns (uint start, uint end, uint cursor)
    {
        uint base;
        assembly ("memory-safe") {
            base := source.offset
        }
        Cursor memory cur = Cursors.openCount(source, i, n);
        return (cur.i - base, cur.end - base, cur.next);
    }

    function testTake(bytes calldata source, uint i, uint n)
        external
        pure
        returns (uint start, uint end, uint cursor, uint next)
    {
        uint base;
        assembly ("memory-safe") {
            base := source.offset
        }
        Cursor memory cur = Cursors.openCount(source, i, n);
        Cursor memory item = cur.take();
        return (item.i - base, item.end - base, item.next, cur.i - base);
    }

    function testResolveRecipient(bytes calldata source, uint i, uint limit, bytes32 backup)
        external
        pure
        returns (bytes32)
    {
        return Cursors.resolveRecipient(source, i, limit, backup);
    }

    function testResolveNode(bytes calldata source, uint i, uint limit, uint backup)
        external
        pure
        returns (uint)
    {
        return Cursors.resolveNode(source, i, limit, backup);
    }

    function testVerifyAuth(bytes calldata source, uint i, uint expectedCid)
        external
        pure
        returns (bytes32 hash, uint deadline, bytes calldata proof)
    {
        Cursor memory input = Cursors.openFrom(source, i);
        return Cursors.resolveAuth(input, expectedCid);
    }

    function testMemParseBalance(bytes memory source, uint i)
        external
        pure
        returns (bytes32 asset, bytes32 meta, uint amount)
    {
        MemRef memory ref = Mem.from(source, i);
        return ref.unpackBalance(source);
    }

    function testMemParseCustody(bytes memory source, uint i) external pure returns (HostAmount memory value) {
        MemRef memory ref = Mem.from(source, i);
        return ref.toCustodyValue(source);
    }

    function testMemSlice(bytes memory source, uint start, uint end_) external pure returns (bytes memory) {
        return Mem.slice(source, start, end_);
    }

    function testMemCount(bytes memory source, uint i, bytes4 key) external pure returns (uint count, uint cursor) {
        return Mem.count(source, i, key);
    }

    function testAllocBalancesFromCount(bytes calldata source, uint i, bytes4 sourceKey)
        external
        pure
        returns (uint count, uint cursor)
    {
        return Cursors.count(source, i, sourceKey);
    }
}




