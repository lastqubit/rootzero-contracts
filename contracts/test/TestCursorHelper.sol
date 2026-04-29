// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { Tx } from "../core/Types.sol";
import { Sizes } from "../blocks/Schema.sol";
import { Keys } from "../blocks/Keys.sol";
import { Cur, Cursors, Writer } from "../Cursors.sol";
import { Writers } from "../blocks/Writers.sol";

using Cursors for Cur;
using Writers for Writer;

contract TestCursorHelper {
    function testWriteBalanceBlock(bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(Sizes.Balance);
        w.appendBalance(asset, meta, amount);
        return w.finish();
    }

    function testWriteCustodyBlock(
        uint host_,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(Sizes.HostAmount);
        w.appendCustody(host_, asset, meta, amount);
        return w.finish();
    }

    function testWriteTxBlock(
        bytes32 from_,
        bytes32 to_,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(Sizes.Transaction);
        w.appendTransaction(Tx({ from: from_, to: to_, asset: asset, meta: meta, amount: amount }));
        return w.finish();
    }

    function testToBountyBlock(uint amount, bytes32 relayer) external pure returns (bytes memory) {
        return Cursors.toBountyBlock(amount, relayer);
    }

    function testToBalanceBlock(bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
        return Cursors.toBalanceBlock(asset, meta, amount);
    }

    function testToCustodyBlock(
        uint host_,
        bytes32 asset,
        bytes32 meta,
        uint amount
    ) external pure returns (bytes memory) {
        return Cursors.toCustodyBlock(host_, asset, meta, amount);
    }

    function testWriterFinishIncomplete() external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(Sizes.Balance);
        return w.finish();
    }

    function testWriterFinish(bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(Sizes.Balance * 2);
        w.appendBalance(asset, meta, amount);
        return w.finish();
    }

    function testWriterRejectsSecond32Block(bytes32 value) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc32s(1);
        w.appendBlock32(Keys.Response, value, 32);
        w.appendBlock32(Keys.Response, value, 32);
        return w.finish();
    }

    function testWriterRejectsOversizedDynamicBlock(bytes memory data) external pure returns (bytes memory) {
        Writer memory w = Writers.allocBytes(1, 32);
        w.appendBlock(Keys.Response, data);
        return w.finish();
    }

    function testUnpackBalance(bytes calldata source) external pure returns (bytes32 asset, bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        return cur.unpackBalance();
    }

    function testUnpackHostAccountAsset(
        bytes calldata source
    ) external pure returns (uint host_, bytes32 account, bytes32 asset, bytes32 meta) {
        Cur memory cur = Cursors.open(source);
        return cur.unpackHostAccountAsset();
    }

    function testUnpackAccountAsset(
        bytes calldata source
    ) external pure returns (bytes32 account, bytes32 asset, bytes32 meta) {
        Cur memory cur = Cursors.open(source);
        return cur.unpackAccountAsset();
    }

    function testUnpackBounds(bytes calldata source) external pure returns (int min, int max) {
        Cur memory cur = Cursors.open(source);
        return cur.unpackBounds();
    }

    function testUnpackFee(bytes calldata source) external pure returns (uint amount) {
        Cur memory cur = Cursors.open(source);
        return cur.unpackFee();
    }

    function testUnpackAccount(bytes calldata source) external pure returns (bytes32 account) {
        Cur memory cur = Cursors.open(source);
        return cur.unpackAccount();
    }

    function testUnpackRaw(bytes calldata source, bytes4 key) external pure returns (bytes calldata data) {
        Cur memory cur = Cursors.open(source);
        return cur.unpackRaw(key);
    }

    function testToTxValue(bytes calldata source) external pure returns (bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount) {
        Cur memory cur = Cursors.open(source);
        Tx memory value = cur.unpackTxValue();
        return (value.from, value.to, value.asset, value.meta, value.amount);
    }

    function testLoad160(bytes calldata source, uint offset)
        external
        pure
        returns (bytes32 a, bytes32 b, bytes32 c, bytes32 d, bytes32 e)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        return Cursors.load160(sourceOffset + offset);
    }

    function testPrimeRun(bytes calldata source, uint group)
        external
        pure
        returns (bytes4 key, uint count, uint quotient, uint offset, uint i, uint len, uint bound)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur = Cursors.open(source);
        (key, count, quotient) = cur.primeRun(group);
        return (key, count, quotient, cur.offset - sourceOffset, cur.i, cur.len, cur.bound);
    }

    function testPeek(bytes calldata source, uint i) external pure returns (bytes4 key, uint len) {
        Cur memory cur = Cursors.open(source);
        return cur.peek(i);
    }

    function testPastCurrent(bytes calldata source) external pure returns (uint) {
        Cur memory cur = Cursors.open(source);
        return cur.past();
    }

    function testHasCurrent(bytes calldata source, bytes4 key) external pure returns (bool) {
        Cur memory cur = Cursors.open(source);
        return cur.has(key);
    }

    function testCountRun(bytes calldata source, uint i, bytes4 key) external pure returns (uint total, uint next) {
        Cur memory cur = Cursors.open(source);
        return cur.countRun(i, key);
    }

    function testSlice(bytes calldata source, uint from, uint to)
        external
        pure
        returns (uint offset, uint i, uint len, uint bound)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur = Cursors.open(source);
        Cur memory out = cur.slice(from, to);
        return (out.offset - sourceOffset, out.i, out.len, out.bound);
    }

    function testBundle(bytes calldata source) external pure returns (uint inputI, uint next) {
        Cur memory cur = Cursors.open(source);
        next = cur.bundle();
        return (cur.i, next);
    }

    function testResume(bytes calldata source, uint end) external pure returns (uint i) {
        Cur memory cur = Cursors.open(source);
        cur.resume(end);
        return cur.i;
    }

    function testResumePastEnd(bytes calldata source, uint end) external pure returns (bool) {
        Cur memory cur = Cursors.open(source);
        cur.i = end + 1;
        cur.resume(end);
        return true;
    }

    function testEnsure(bytes calldata source, uint at) external pure returns (uint i) {
        Cur memory cur = Cursors.open(source);
        cur.i = at;
        cur.ensure(at);
        return cur.i;
    }

    function testEnsureMismatch(bytes calldata source, uint at) external pure returns (bool) {
        Cur memory cur = Cursors.open(source);
        if (at < cur.len) {
            cur.i = at + 1;
        }
        cur.ensure(at);
        return true;
    }

    function testList(bytes calldata source) external pure returns (uint inputI, uint next) {
        Cur memory cur = Cursors.open(source);
        next = cur.list();
        return (cur.i, next);
    }

    function testTake(bytes calldata source, bytes4 key)
        external
        pure
        returns (uint outOffset, uint outI, uint outLen, uint outBound, uint inputI)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur = Cursors.open(source);
        Cur memory out = cur.take(key);
        return (out.offset - sourceOffset, out.i, out.len, out.bound, cur.i);
    }

    function testMaybeRoute(bytes calldata source)
        external
        pure
        returns (uint outOffset, uint outI, uint outLen, uint outBound, uint inputI)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur = Cursors.open(source);
        Cur memory out = cur.maybeRoute();
        return (out.offset - sourceOffset, out.i, out.len, out.bound, cur.i);
    }

    function testListPrime(bytes calldata source, uint group)
        external
        pure
        returns (uint inputI, uint bound, uint count, uint next)
    {
        Cur memory cur = Cursors.open(source);
        (count, next) = cur.list(group);
        return (cur.i, cur.bound, count, next);
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
        amount = cur.requireAssetAmount(Keys.Amount, asset, meta);
        i = cur.i;
    }

    function testRequireAuth(bytes calldata source, uint cid) external pure returns (uint deadline, bytes calldata proof, uint i) {
        Cur memory cur = Cursors.open(source);
        (deadline, proof) = cur.requireAuth(cid);
        return (deadline, proof, cur.i);
    }

    function testNodeAfter(bytes calldata source, uint group, uint backup) external pure returns (uint) {
        Cur memory cur = Cursors.open(source);
        cur.primeRun(group);
        return cur.nodeAfter(backup);
    }

    function testAccountAfter(bytes calldata source, uint group, bytes32 backup) external pure returns (bytes32 account) {
        Cur memory cur = Cursors.open(source);
        cur.primeRun(group);
        return cur.accountAfter(backup);
    }

    function testAuthLast(
        bytes calldata source,
        uint group,
        uint cid
    ) external pure returns (bytes32 hash, uint deadline, bytes calldata proof) {
        Cur memory cur = Cursors.open(source);
        cur.primeRun(group);
        return cur.authLast(cid);
    }

    function testCursorCompleteEmpty(bytes calldata source, uint group) external pure returns (bool) {
        Cur memory cur = Cursors.open(source);
        cur.primeRun(group);
        cur.complete();
        return true;
    }

    function testCursorCompletePartial(bytes calldata source, uint group) external pure returns (bool) {
        Cur memory cur = Cursors.open(source);
        cur.primeRun(group);
        if (cur.bound > 0) {
            (, uint len) = cur.peek(cur.i);
            cur.i += 8 + len;
        }
        cur.complete();
        return true;
    }

    function testCursorCompleteConsumed(bytes calldata source, uint group) external pure returns (bool) {
        Cur memory cur = Cursors.open(source);
        cur.primeRun(group);
        while (cur.i < cur.bound) {
            (, uint len) = cur.peek(cur.i);
            cur.i += 8 + len;
        }
        cur.complete();
        return true;
    }

    function testCursorEndPartial(bytes calldata source) external pure returns (bool) {
        Cur memory cur = Cursors.open(source);
        if (cur.len > 0) {
            (, uint len) = cur.peek(cur.i);
            cur.i += 8 + len;
        }
        cur.end();
        return true;
    }

    function testCursorEndConsumed(bytes calldata source) external pure returns (bool) {
        Cur memory cur = Cursors.open(source);
        while (cur.i < cur.len) {
            (, uint len) = cur.peek(cur.i);
            cur.i += 8 + len;
        }
        cur.end();
        return true;
    }

}
