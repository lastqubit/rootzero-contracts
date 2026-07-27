// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { HostAmount, Tx } from "../core/Types.sol";
import { Sizes, Specs } from "../codec/Specs.sol";
import { Keys } from "../codec/Keys.sol";
import { Blocks, Cur, Cursors, Reader, Readers, Writer } from "../Cursors.sol";
import {Lanes} from "../execution/Execution.sol";
import {Spans} from "../utils/Spans.sol";
import { Writers } from "../codec/Writers.sol";

using Cursors for Cur;
using Readers for Reader;
using Writers for Writer;

contract TestCursorHelper {
    function tagged(uint cur, uint8 tag) private pure returns (uint created) {
        (uint i, uint offset, uint len) = Spans.decode(cur);
        (uint groups, uint8 flags, ) = Spans.meta(cur);
        created = Spans.seek(Spans.create(offset, len, groups, flags, tag), i);
    }

    function testCursorLanes(
        uint input,
        uint state,
        uint stateI
    ) external pure returns (uint selected, uint restored) {
        input = tagged(input, Lanes.Input);
        state = tagged(state, Lanes.State);
        selected = Spans.select(Spans.pair(input, state), Lanes.State);
        selected = Spans.seek(selected, stateI);
        restored = Spans.select(selected, Lanes.Input);
    }

    function testSelectTag(
        uint lower,
        uint8 lowerTag,
        uint higher,
        uint8 higherTag,
        uint8 expected
    ) external pure returns (uint) {
        lower = Spans.create(0, lower, 0, 0, lowerTag);
        higher = Spans.create(0, higher, 0, 0, higherTag);
        return Spans.select(Spans.pair(lower, higher), expected);
    }

    function testSpanMeta(
        uint groups,
        uint8 flags,
        uint8 tag
    ) external pure returns (uint cur, uint decodedGroups, uint8 decodedFlags, uint8 decodedTag) {
        cur = Spans.create(0, 0, groups, flags, tag);
        (decodedGroups, decodedFlags, decodedTag) = Spans.meta(cur);
    }

    function testSpanInitial(uint cur) external pure returns (bool) {
        return Spans.initial(cur);
    }

    function testWriteBalanceBlock(bytes32 asset, uint amount) external pure returns (bytes memory) {
        Writer memory w = Writers.init(Specs.Balance, 1);
        w.appendBalance(asset, amount);
        return w.finish();
    }

    function testWriteCustodyBlock(
        uint host_,
        bytes32 asset,
        uint amount
    ) external pure returns (bytes memory) {
        Writer memory w = Writers.init(Specs.Custody, 1);
        w.appendCustody(host_, asset, amount);
        return w.finish();
    }

    function testWriteTxBlock(
        bytes32 from_,
        bytes32 to_,
        bytes32 asset,
        uint amount
    ) external pure returns (bytes memory) {
        Writer memory w = Writers.init(Specs.Transaction, 1);
        w.appendTransaction(from_, to_, asset, amount);
        return w.finish();
    }

    function testWriteTxStructBlock(
        bytes32 from_,
        bytes32 to_,
        bytes32 asset,
        uint amount
    ) external pure returns (bytes memory) {
        Writer memory w = Writers.init(Specs.Transaction, 1);
        w.appendTransaction(Tx({ from: from_, to: to_, asset: asset, amount: amount }));
        return w.finish();
    }

    function testToBountyBlock(uint amount, bytes32 relayer) external pure returns (bytes memory) {
        return Blocks.bounty(amount, relayer);
    }

    function testToDispatchBlock(uint portal, uint resources, bytes memory payload) external pure returns (bytes memory) {
        return Blocks.dispatch(portal, resources, payload);
    }

    function testToBalanceBlock(bytes32 asset, uint amount) external pure returns (bytes memory) {
        return Blocks.balance(asset, amount);
    }

    function testToCustodyBlock(
        uint host_,
        bytes32 asset,
        uint amount
    ) external pure returns (bytes memory) {
        return Blocks.custody(host_, asset, amount);
    }

    function testToTransactionBlock(
        bytes32 from_,
        bytes32 to_,
        bytes32 asset,
        uint amount
    ) external pure returns (bytes memory) {
        return Blocks.transaction(from_, to_, asset, amount);
    }

    function testWriterFinishEmpty() external pure returns (bytes memory) {
        Writer memory w = Writers.init(Specs.Balance, 1);
        return w.finish();
    }

    function testWriterFinish(bytes32 asset, uint amount) external pure returns (bytes memory) {
        Writer memory w = Writers.init(Specs.Balance, 2);
        w.appendBalance(asset, amount);
        return w.finish();
    }

    function testUnpackBalance(bytes calldata source) external pure returns (bytes32 asset, uint amount) {
        Cur memory cur = Cursors.openCur(source);
        return cur.unpackBalance();
    }

    function testReaderUnpackBalance(
        bytes calldata source
    ) external pure returns (bytes32 asset, uint amount, uint i, bool done) {
        Reader memory cur = Readers.open(bytes(source));
        (asset, amount) = cur.unpackBalance();
        return (asset, amount, cur.i, cur.done());
    }

    function testReaderUnpackTwoBalances(
        bytes calldata source
    )
        external
        pure
        returns (bytes32 firstAsset, uint firstAmount, bytes32 secondAsset, uint secondAmount, uint i, bool done)
    {
        Reader memory cur = Readers.open(bytes(source));
        (firstAsset, firstAmount) = cur.unpackBalance();
        (secondAsset, secondAmount) = cur.unpackBalance();
        return (firstAsset, firstAmount, secondAsset, secondAmount, cur.i, cur.done());
    }

    function testReaderUnpackTransaction(
        bytes calldata source
    ) external pure returns (bytes32 from, bytes32 to, bytes32 asset, uint amount, uint i, bool done) {
        Reader memory cur = Readers.open(bytes(source));
        (from, to, asset, amount) = cur.unpackTransaction();
        return (from, to, asset, amount, cur.i, cur.done());
    }

    function testUnpackBalanceForHost(
        bytes calldata source,
        uint host_
    ) external pure returns (uint host, bytes32 asset, uint amount, uint i) {
        Cur memory cur = Cursors.openCur(source);
        HostAmount memory value = cur.unpackBalanceForHost(host_);
        (i, , ) = Spans.decode(cur.packed);
        return (value.host, value.asset, value.amount, i);
    }

    function testUnpackHostAccountAsset(
        bytes calldata source
    ) external pure returns (uint host_, bytes32 account, bytes32 asset) {
        Cur memory cur = Cursors.openCur(source);
        return cur.unpackHostAccountAsset();
    }

    function testUnpackAccountAsset(
        bytes calldata source
    ) external pure returns (bytes32 account, bytes32 asset) {
        Cur memory cur = Cursors.openCur(source);
        return cur.unpackAccountAsset();
    }

    function testUnpackFee(bytes calldata source) external pure returns (uint amount) {
        Cur memory cur = Cursors.openCur(source);
        return cur.unpackFee();
    }

    function testUnpackAccount(bytes calldata source) external pure returns (bytes32 account) {
        Cur memory cur = Cursors.openCur(source);
        return cur.unpackAccount();
    }

    function testToTxValue(bytes calldata source) external pure returns (bytes32 from_, bytes32 to_, bytes32 asset, uint amount) {
        Cur memory cur = Cursors.openCur(source);
        Tx memory value = cur.unpackTxValue();
        return (value.from, value.to, value.asset, value.amount);
    }

    function testScope(bytes calldata source, uint group)
        external
        pure
        returns (bytes4 key, uint groups, uint offset, uint i, uint len)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur = Cursors.openCur(source);
        (i, offset, len) = Spans.decode(cur.packed);
        key = i + 4 > len ? bytes4(0) : bytes4(msg.data[offset + i:offset + i + 4]);
        groups = cur.scope(key, group);
        (i, offset, len) = Spans.decode(cur.packed);
        return (key, groups, offset - sourceOffset, i, len);
    }

    function testOpenAt(bytes calldata source, uint i)
        external
        pure
        returns (uint offset, uint cursorI, uint len)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur = Cursors.openCur(source, i);
        (cursorI, offset, len) = Spans.decode(cur.packed);
        return (offset - sourceOffset, cursorI, len);
    }

    function testInit(bytes calldata source, uint group, uint expected)
        external
        pure
        returns (uint offset, uint cursorI, uint len, uint groups)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur;
        (cur, groups) = Cursors.init(source, group, expected);
        (cursorI, offset, len) = Spans.decode(cur.packed);
        return (offset - sourceOffset, cursorI, len, groups);
    }

    function testPeek(bytes calldata source, uint i) external pure returns (bytes4 key, uint len) {
        Cur memory cur = Cursors.openCur(source);
        return cur.peek(i);
    }

    function testPastCurrent(bytes calldata source) external pure returns (uint) {
        Cur memory cur = Cursors.openCur(source);
        return cur.past();
    }

    function testIsAtCurrent(bytes calldata source, bytes4 key) external pure returns (bool) {
        Cur memory cur = Cursors.openCur(source);
        return cur.isAt(key);
    }

    function testHasAt(bytes calldata source, uint i, bytes4 key) external pure returns (bool) {
        Cur memory cur = Cursors.openCur(source);
        return cur.hasAt(i, key);
    }

    function testRun(bytes calldata source, uint i, bytes4 key) external pure returns (uint total, uint next) {
        Cur memory cur = Cursors.openCur(source);
        return cur.run(i, key);
    }

    function testSlice(bytes calldata source, uint from, uint to)
        external
        pure
        returns (uint offset, uint i, uint len)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur = Cursors.openCur(source);
        Cur memory out = cur.slice(from, to);
        (i, offset, len) = Spans.decode(out.packed);
        return (offset - sourceOffset, i, len);
    }

    function testRaw(bytes calldata source) external pure returns (bytes calldata data) {
        Cur memory cur = Cursors.openCur(source);
        return cur.raw();
    }

    function testRawSlice(bytes calldata source, uint from, uint to) external pure returns (bytes calldata data) {
        Cur memory cur = Cursors.openCur(source);
        return cur.raw(from, to);
    }

    function testMaybeOnly(bytes calldata source, bytes4 key) external pure returns (bool) {
        Cur memory cur = Cursors.openCur(source);
        return cur.maybeOnly(key);
    }

    function testSkipTo(bytes calldata source, uint end) external pure returns (uint i) {
        Cur memory cur = Cursors.openCur(source);
        cur = cur.skipTo(end);
        (i, , ) = Spans.decode(cur.packed);
    }

    function testSkipToPastEnd(bytes calldata source, uint end) external pure returns (bool) {
        Cur memory cur = Cursors.openCur(source);
        cur.packed = (cur.packed & ~uint(type(uint32).max)) | (end + 1);
        cur.skipTo(end);
        return true;
    }

    function testEnsureAt(bytes calldata source, uint pos) external pure returns (uint i) {
        Cur memory cur = Cursors.openCur(source);
        cur.packed = (cur.packed & ~uint(type(uint32).max)) | pos;
        cur.ensureAt(pos);
        (i, , ) = Spans.decode(cur.packed);
    }

    function testEnsureAtMismatch(bytes calldata source, uint pos) external pure returns (bool) {
        Cur memory cur = Cursors.openCur(source);
        (, , uint len) = Spans.decode(cur.packed);
        if (pos < len) {
            cur.packed = (cur.packed & ~uint(type(uint32).max)) | (pos + 1);
        }
        cur.ensureAt(pos);
        return true;
    }

    function testList(bytes calldata source)
        external
        pure
        returns (uint itemsOffset, uint itemsI, uint itemsLen, uint inputI)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur = Cursors.openCur(source);
        Cur memory items = cur.list();
        uint offset;
        (itemsI, offset, itemsLen) = Spans.decode(items.packed);
        (inputI, , ) = Spans.decode(cur.packed);
        return (offset - sourceOffset, itemsI, itemsLen, inputI);
    }

    function testTake(bytes calldata source, bytes4 key)
        external
        pure
        returns (uint outOffset, uint outI, uint outLen, uint inputI)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur = Cursors.openCur(source);
        Cur memory out = cur.take(key);
        uint offset;
        (outI, offset, outLen) = Spans.decode(out.packed);
        (inputI, , ) = Spans.decode(cur.packed);
        return (offset - sourceOffset, outI, outLen, inputI);
    }

    function testMaybeTake(bytes calldata source, bytes4 key)
        external
        pure
        returns (uint outOffset, uint outI, uint outLen, uint inputI)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur = Cursors.openCur(source);
        Cur memory out = cur.maybeTake(key);
        uint offset;
        (outI, offset, outLen) = Spans.decode(out.packed);
        (inputI, , ) = Spans.decode(cur.packed);
        return (offset - sourceOffset, outI, outLen, inputI);
    }

    function testUnpackStep(
        bytes calldata source
    ) external pure returns (uint target, uint resources, bytes calldata req, uint i) {
        Cur memory cur = Cursors.openCur(source);
        (target, resources, req) = cur.unpackStep();
        (i, , ) = Spans.decode(cur.packed);
    }

    function testUnpackContext(bytes calldata source)
        external
        pure
        returns (bytes32 account, bytes calldata state, bytes calldata request, uint i)
    {
        Cur memory cur = Cursors.openCur(source);
        (account, state, request) = cur.unpackContext();
        (i, , ) = Spans.decode(cur.packed);
    }

    function testUnpackRecover(bytes calldata source)
        external
        pure
        returns (uint handler, uint resources, bytes32 key, bytes calldata witness, uint i)
    {
        Cur memory cur = Cursors.openCur(source);
        (handler, resources, key, witness) = cur.unpackRecover();
        (i, , ) = Spans.decode(cur.packed);
    }

    function testUnpackRelay(bytes calldata source)
        external
        pure
        returns (uint portal, uint resources, bytes calldata request, uint i)
    {
        Cur memory cur = Cursors.openCur(source);
        (portal, resources, request) = cur.unpackRelay();
        (i, , ) = Spans.decode(cur.packed);
    }

    function testUnpackDispatch(bytes calldata source)
        external
        pure
        returns (uint portal, uint resources, bytes calldata payload, uint i)
    {
        Cur memory cur = Cursors.openCur(source);
        (portal, resources, payload) = cur.unpackDispatch();
        (i, , ) = Spans.decode(cur.packed);
    }

    function testRequireAmount(
        bytes calldata source,
        bytes32 asset
    ) external pure returns (uint amount, uint i) {
        Cur memory cur = Cursors.openCur(source);
        amount = cur.requireAssetAmount(Specs.Amount, asset);
        (i, , ) = Spans.decode(cur.packed);
    }

    function testEnsureBalanceLimit(
        bytes calldata source,
        bytes32 asset,
        uint amount
    ) external pure returns (uint i) {
        Cur memory cur = Cursors.openCur(source);
        cur.ensureBalanceLimit(asset, amount);
        (i, , ) = Spans.decode(cur.packed);
    }

    function testEnsureCustodyLimit(
        bytes calldata source,
        uint host_,
        bytes32 asset,
        uint amount
    ) external pure returns (uint i) {
        Cur memory cur = Cursors.openCur(source);
        cur.ensureCustodyLimit(host_, asset, amount);
        (i, , ) = Spans.decode(cur.packed);
    }

    function testRequireAuth(bytes calldata source, uint cid) external pure returns (uint deadline, bytes calldata proof, uint i) {
        Cur memory cur = Cursors.openCur(source);
        (deadline, proof) = cur.requireAuth(cid);
        (i, , ) = Spans.decode(cur.packed);
    }

    function testCursorCompleteRunEmpty(bytes calldata source, uint group) external pure returns (bool) {
        Cur memory cur = Cursors.openCur(source);
        (uint i, uint offset, uint len) = Spans.decode(cur.packed);
        bytes4 key = i + 4 > len ? bytes4(0) : bytes4(msg.data[offset + i:offset + i + 4]);
        cur.scope(key, group);
        cur.complete();
        return true;
    }

    function testCursorCompleteRunPartial(bytes calldata source, uint group) external pure returns (bool) {
        Cur memory cur = Cursors.openCur(source);
        (uint i, uint offset, uint len) = Spans.decode(cur.packed);
        bytes4 key = i + 4 > len ? bytes4(0) : bytes4(msg.data[offset + i:offset + i + 4]);
        cur.scope(key, group);
        (i, , len) = Spans.decode(cur.packed);
        if (len > 0) {
            (, uint size) = cur.peek(i);
            cur.skip(8 + size);
        }
        cur.complete();
        return true;
    }

    function testCursorCompleteRunConsumed(bytes calldata source, uint group) external pure returns (bool) {
        Cur memory cur = Cursors.openCur(source);
        (uint i, uint offset, uint len) = Spans.decode(cur.packed);
        bytes4 key = i + 4 > len ? bytes4(0) : bytes4(msg.data[offset + i:offset + i + 4]);
        cur.scope(key, group);
        while (cur.more()) {
            (i, , ) = Spans.decode(cur.packed);
            (, uint size) = cur.peek(i);
            cur.skip(8 + size);
        }
        cur.complete();
        return true;
    }

    function testCursorCompletePartial(bytes calldata source) external pure returns (bool) {
        Cur memory cur = Cursors.openCur(source);
        (uint i, , uint len) = Spans.decode(cur.packed);
        if (len > 0) {
            (, uint size) = cur.peek(i);
            cur.skip(8 + size);
        }
        cur.complete();
        return true;
    }

    function testCursorCompleteConsumed(bytes calldata source) external pure returns (bool) {
        Cur memory cur = Cursors.openCur(source);
        while (cur.more()) {
            (uint i, , ) = Spans.decode(cur.packed);
            (, uint len) = cur.peek(i);
            cur.skip(8 + len);
        }
        cur.complete();
        return true;
    }

}
