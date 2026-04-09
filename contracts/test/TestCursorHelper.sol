// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { HostAmount, Tx } from "../blocks/Schema.sol";
import { Cur, Cursors, Writer } from "../Cursors.sol";
import { MemRef, Mem } from "../blocks/Mem.sol";
import { Writers, BALANCE_BLOCK_LEN, CUSTODY_BLOCK_LEN, TX_BLOCK_LEN } from "../blocks/Writers.sol";

using Cursors for Cur;
using Writers for Writer;
using Mem for MemRef;

contract TestCursorHelper {
    function testBlockHeader(bytes4 key, uint len) external pure returns (uint) {
        return Writers.toBlockHeader(key, len);
    }

    function testWriteBalanceBlock(bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(BALANCE_BLOCK_LEN);
        w.appendBalance(asset, meta, amount);
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

    function testWriterFinishIncomplete() external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(BALANCE_BLOCK_LEN);
        return Writers.finish(w);
    }

    function testWriterFinish(bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(BALANCE_BLOCK_LEN * 2);
        w.appendBalance(asset, meta, amount);
        return Writers.finish(w);
    }

    function testUnpackBalance(bytes calldata source) external pure returns (bytes32 asset, bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        return cur.unpackBalance();
    }

    function testToTxValue(bytes calldata source) external pure returns (bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        Tx memory value = cur.unpackTxValue();
        return (value.from, value.to, value.asset, value.meta, value.amount);
    }

    function testInit(bytes calldata source, uint primeGroup)
        external
        pure
        returns (bytes4 key, uint count, uint offset, uint i, uint len, uint bound)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur;
        (cur, key, count) = Cursors.init(source, primeGroup);
        return (key, count, cur.offset - sourceOffset, cur.i, cur.len, cur.bound);
    }

    function testPeek(bytes calldata source, uint i) external pure returns (bytes4 key, uint len) {
        Cur memory cur = Cursors.open(source);
        return cur.peek(i);
    }

    function testCountRun(bytes calldata source, uint i, bytes4 key) external pure returns (uint total, uint next) {
        Cur memory cur = Cursors.open(source).seek(i);
        return cur.countRun(key);
    }

    function testBundle(bytes calldata source) external pure returns (uint inputI, uint offset, uint len) {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur = Cursors.open(source);
        Cur memory out = cur.bundle();
        return (cur.i, out.offset - sourceOffset, out.len);
    }

    function testUnpackStep(bytes calldata source) external pure returns (uint target, uint value, bytes calldata req, uint i) {
        Cur memory cur = Cursors.open(source);
        (target, value, req) = cur.unpackStep();
        return (target, value, req, cur.i);
    }

    function testRequireAmount(
        bytes calldata source,
        bytes32 asset,
        bytes32 meta
    ) external pure returns (uint amount, uint i) {
        Cur memory cur = Cursors.open(source);
        amount = cur.requireAmount(asset, meta);
        i = cur.i;
    }

    function testRequireAuth(bytes calldata source, uint cid) external pure returns (uint deadline, bytes calldata proof, uint i) {
        Cur memory cur = Cursors.open(source);
        (deadline, proof) = cur.requireAuth(cid);
        return (deadline, proof, cur.i);
    }

    function testNodeAfter(bytes calldata source, uint primeGroup, uint backup) external pure returns (uint) {
        (Cur memory cur, , ) = Cursors.init(source, primeGroup);
        return cur.nodeAfter(backup);
    }

    function testRecipientAfter(bytes calldata source, uint primeGroup, bytes32 backup) external pure returns (bytes32) {
        (Cur memory cur, , ) = Cursors.init(source, primeGroup);
        return cur.recipientAfter(backup);
    }

    function testAuthLast(
        bytes calldata source,
        uint primeGroup,
        uint cid
    ) external pure returns (bytes32 hash, uint deadline, bytes calldata proof) {
        (Cur memory cur, , ) = Cursors.init(source, primeGroup);
        return cur.authLast(cid);
    }

    function testCursorCompleteEmpty(bytes calldata source, uint primeGroup) external pure returns (bool) {
        (Cur memory cur, , ) = Cursors.init(source, primeGroup);
        cur.complete();
        return true;
    }

    function testCursorCompletePartial(bytes calldata source, uint primeGroup) external pure returns (bool) {
        (Cur memory cur, , ) = Cursors.init(source, primeGroup);
        if (cur.bound > 0) {
            (, uint len) = cur.peek(cur.i);
            cur.i += 8 + len;
        }
        cur.complete();
        return true;
    }

    function testCursorCompleteConsumed(bytes calldata source, uint primeGroup) external pure returns (bool) {
        (Cur memory cur, , ) = Cursors.init(source, primeGroup);
        while (cur.i < cur.bound) {
            (, uint len) = cur.peek(cur.i);
            cur.i += 8 + len;
        }
        cur.complete();
        return true;
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
}
