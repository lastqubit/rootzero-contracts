// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import { HostAmount, Tx } from "../core/Types.sol";
import { Specs } from "../codec/Specs.sol";
import { Blocks, Cur, Decoders, Reader, Readers, Writer } from "../Codec.sol";
import {Lanes} from "../execution/Execution.sol";
import {Cursors} from "../utils/Cursors.sol";
import { Writers } from "../codec/Writers.sol";

using Decoders for Cur;
using Readers for Reader;
using Writers for Writer;
using Cursors for uint;

contract TestCursorHelper {
    function tagged(uint cur, uint8 tag) private pure returns (uint created) {
        (uint i, uint offset, uint len) = Cursors.decode(cur);
        (uint groups, uint8 flags, ) = Cursors.meta(cur);
        created = Cursors.seek(Cursors.create(offset, len, groups, flags, tag), i);
    }

    function testCursorLanes(
        uint input,
        uint state,
        uint stateI
    ) external pure returns (uint selected, uint restored) {
        input = tagged(input, Lanes.Input);
        state = tagged(state, Lanes.State);
        selected = Cursors.select(Cursors.pair(input, state), Lanes.State);
        selected = Cursors.seek(selected, stateI);
        restored = Cursors.select(selected, Lanes.Input);
    }

    function testSelectTag(
        uint lower,
        uint8 lowerTag,
        uint higher,
        uint8 higherTag,
        uint8 expected
    ) external pure returns (uint) {
        lower = Cursors.create(0, lower, 0, 0, lowerTag);
        higher = Cursors.create(0, higher, 0, 0, higherTag);
        return Cursors.select(Cursors.pair(lower, higher), expected);
    }

    function testPair(uint low, uint high) external pure returns (uint) {
        return Cursors.pair(low, high);
    }

    function testContains(uint cur, uint8 tag) external pure returns (bool) {
        return Cursors.contains(cur, tag);
    }

    function testSpanMeta(
        uint groups,
        uint8 flags,
        uint8 tag
    ) external pure returns (uint cur, uint decodedGroups, uint8 decodedFlags, uint8 decodedTag) {
        cur = Cursors.create(0, 0, groups, flags, tag);
        (decodedGroups, decodedFlags, decodedTag) = Cursors.meta(cur);
    }

    function testFrame() external pure returns (uint) {
        uint low = Cursors.create(10, 20, 3, 4, 1).seek(5);
        uint high = Cursors.create(100, 30, 6, 7, 2).seek(8);
        return Cursors.pair(low, high).frame();
    }

    function testMarkBefore(
        uint current,
        uint target,
        bool pairedMark
    ) external pure returns (uint matched, bool pending) {
        uint low = Cursors.create(10, 20, 3, 4, 1).seek(5);
        uint high = Cursors.create(100, 30, 6, 7, 2).seek(current);
        uint cursors = Cursors.pair(low, high);
        uint mark = Cursors.create(100, 30, 6, 7, 2).seek(target);
        if (pairedMark) mark = Cursors.pair(mark, low);

        matched = cursors.locate(mark);
        pending = cursors.before(mark);
    }

    function testMissingMark() external pure returns (bool) {
        uint cur = Cursors.create(10, 20, 0, 0, 1);
        uint mark = Cursors.create(11, 20, 0, 0, 1);
        cur.before(mark);
        return true;
    }

    function testZeroMark(uint cur) external pure returns (uint) {
        return cur.locate(0);
    }

    function testZeroBefore(uint cur) external pure returns (bool) {
        return cur.before(0);
    }

    function testSpanInitial(uint cur) external pure returns (bool) {
        return Cursors.initial(cur);
    }

    /// @notice Exercise cursor consumption and report the resulting position.
    function testCursorNavigation(
        uint offset,
        uint len,
        uint i,
        uint amount
    ) external pure returns (uint next, uint abs, bool more) {
        uint cur = Cursors.create(offset, len, 0, 0, 0).seek(i);
        (cur, abs) = cur.consume(amount);
        (next, , ) = cur.decode();
        more = cur.more();
    }

    /// @notice Exercise cursor resizing at an existing position.
    function testCursorResize(uint len, uint i, uint resized) external pure returns (uint next, uint capacity) {
        uint cur = Cursors.create(0, len, 0, 0, 0).seek(i).resize(resized);
        (next, , capacity) = cur.decode();
    }

    /// @notice Return whether either constructed cursor lane has bytes remaining.
    function testCursorAny(uint lowlen, uint lowi, uint highlen, uint highi) external pure returns (bool) {
        uint low = Cursors.create(0, lowlen, 0, 0, 1).seek(lowi);
        uint high = Cursors.create(0, highlen, 0, 0, 2).seek(highi);
        return Cursors.pair(low, high).any();
    }

    /// @notice Reconcile constructed cursor lane groups with an expected count.
    function testReconcile(uint lowgroups, uint highgroups, uint expected) external pure returns (uint) {
        uint low = Cursors.create(0, 0, lowgroups, 0, 1);
        uint high = Cursors.create(0, 0, highgroups, 0, 2);
        return Cursors.reconcile(Cursors.pair(low, high), expected);
    }

    /// @notice Select and consume a constructed tagged cursor lane.
    function testConsumeTag(
        uint lowoffset,
        uint lowlen,
        uint highoffset,
        uint highlen,
        uint8 tag,
        uint amount
    ) external pure returns (uint updated, uint abs) {
        uint low = Cursors.create(lowoffset, lowlen, 0, 0, 1);
        uint high = Cursors.create(highoffset, highlen, 0, 0, 2);
        return Cursors.consume(Cursors.pair(low, high), tag, amount);
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

    function testToDispatchBlock(uint portal, uint resources, bytes memory payload) external pure returns (bytes memory) {
        return Blocks.dispatch(portal, resources, payload);
    }

    function testToBalanceBlock(bytes32 asset, uint amount) external pure returns (bytes memory) {
        return Blocks.balance(asset, amount);
    }

    function testToLabelBlock(bytes32 namespace, string memory name) external pure returns (bytes memory) {
        return Blocks.label(namespace, name);
    }

    function testToActionBlock(uint value) external pure returns (bytes memory) {
        return Blocks.action(value);
    }

    function testToSchemaBlock(uint spec, string memory body, bytes32 name) external pure returns (bytes memory) {
        return Blocks.schema(spec, body, name);
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
        Cur memory cur = Decoders.wrap(source);
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
        Cur memory cur = Decoders.wrap(source);
        HostAmount memory value = cur.unpackBalanceForHost(host_);
        (i, , ) = Cursors.decode(cur.state);
        return (value.host, value.asset, value.amount, i);
    }

    function testUnpackHostAccountAsset(
        bytes calldata source
    ) external pure returns (uint host_, bytes32 account, bytes32 asset) {
        Cur memory cur = Decoders.wrap(source);
        return cur.unpackHostAccountAsset();
    }

    function testUnpackAccountAsset(
        bytes calldata source
    ) external pure returns (bytes32 account, bytes32 asset) {
        Cur memory cur = Decoders.wrap(source);
        return cur.unpackAccountAsset();
    }

    function testUnpackAccount(bytes calldata source) external pure returns (bytes32 account) {
        Cur memory cur = Decoders.wrap(source);
        return cur.unpackAccount();
    }

    function testToTxValue(bytes calldata source) external pure returns (bytes32 from_, bytes32 to_, bytes32 asset, uint amount) {
        Cur memory cur = Decoders.wrap(source);
        Tx memory value = cur.unpackTransactionValue();
        return (value.from, value.to, value.asset, value.amount);
    }

    function testWrapAt(bytes calldata source, uint i)
        external
        pure
        returns (uint offset, uint cursorI, uint len)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur = Decoders.wrap(source, i);
        (cursorI, offset, len) = Cursors.decode(cur.state);
        return (offset - sourceOffset, cursorI, len);
    }

    function testOpen(bytes calldata source, uint stride)
        external
        pure
        returns (uint offset, uint cursorI, uint len, uint groups)
    {
        uint sourceOffset;
        assembly ("memory-safe") {
            sourceOffset := source.offset
        }
        Cur memory cur;
        cur = Decoders.open(source, stride);
        (cursorI, offset, len) = Cursors.decode(cur.state);
        (groups, , ) = Cursors.meta(cur.state);
        if (cur.state != 0) offset -= sourceOffset;
        return (offset, cursorI, len, groups);
    }

    function testPeek(bytes calldata source, uint i) external pure returns (bytes4 key, uint len) {
        Cur memory cur = Decoders.wrap(source);
        return cur.peek(i);
    }

    function testPastCurrent(bytes calldata source) external pure returns (uint) {
        Cur memory cur = Decoders.wrap(source);
        return cur.past();
    }

    function testIsAtCurrent(bytes calldata source, bytes4 key) external pure returns (bool) {
        Cur memory cur = Decoders.wrap(source);
        return cur.isAt(key);
    }

    function testHasAt(bytes calldata source, uint i, bytes4 key) external pure returns (bool) {
        Cur memory cur = Decoders.wrap(source);
        return cur.hasAt(i, key);
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
        Cur memory cur = Decoders.wrap(source);
        Cur memory out = cur.slice(from, to);
        (i, offset, len) = Cursors.decode(out.state);
        return (offset - sourceOffset, i, len);
    }

    function testRaw(bytes calldata source) external pure returns (bytes calldata data) {
        Cur memory cur = Decoders.wrap(source);
        return cur.raw();
    }

    function testRawSlice(bytes calldata source, uint from, uint to) external pure returns (bytes calldata data) {
        Cur memory cur = Decoders.wrap(source);
        return cur.raw(from, to);
    }

    function testSeek(bytes calldata source, uint end) external pure returns (uint i) {
        Cur memory cur = Decoders.wrap(source);
        cur.state = cur.state.seek(end);
        (i, , ) = Cursors.decode(cur.state);
    }

    function testSeekBackward(bytes calldata source, uint end) external pure returns (bool) {
        Cur memory cur = Decoders.wrap(source);
        cur.state = (cur.state & ~uint(type(uint32).max)) | (end + 1);
        cur.state.seek(end);
        return true;
    }

    function testExpectPosition(bytes calldata source, uint pos) external pure returns (uint i) {
        Cur memory cur = Decoders.wrap(source);
        cur.state = (cur.state & ~uint(type(uint32).max)) | pos;
        cur.state.expect(pos);
        (i, , ) = Cursors.decode(cur.state);
    }

    function testExpectPositionMismatch(bytes calldata source, uint pos) external pure returns (bool) {
        Cur memory cur = Decoders.wrap(source);
        (, , uint len) = Cursors.decode(cur.state);
        if (pos < len) {
            cur.state = (cur.state & ~uint(type(uint32).max)) | (pos + 1);
        }
        cur.state.expect(pos);
        return true;
    }

    function testExpectAbsolute(bytes calldata source, uint pos) external pure returns (uint abs) {
        Cur memory cur = Decoders.wrap(source);
        cur.state = cur.state.seek(pos);
        abs = cur.state.absolute();
        cur.state.expectAbs(abs);
    }

    function testExpectAbsoluteMismatch(bytes calldata source) external pure returns (bool) {
        Cur memory cur = Decoders.wrap(source);
        cur.state.expectAbs(cur.state.absolute() + 1);
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
        Cur memory cur = Decoders.wrap(source);
        Cur memory items = cur.list();
        uint offset;
        (itemsI, offset, itemsLen) = Cursors.decode(items.state);
        (inputI, , ) = Cursors.decode(cur.state);
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
        Cur memory cur = Decoders.wrap(source);
        Cur memory out = cur.take(key);
        uint offset;
        (outI, offset, outLen) = Cursors.decode(out.state);
        (inputI, , ) = Cursors.decode(cur.state);
        return (offset - sourceOffset, outI, outLen, inputI);
    }

    function testUnpackStep(
        bytes calldata source
    ) external pure returns (uint cmd, uint resources, bytes calldata input, uint i) {
        Cur memory cur = Decoders.wrap(source);
        (cmd, resources, input) = cur.unpackStep();
        (i, , ) = Cursors.decode(cur.state);
    }

    function testUnpackContext(bytes calldata source)
        external
        pure
        returns (bytes32 account, bytes calldata state, bytes calldata input, uint i)
    {
        Cur memory cur = Decoders.wrap(source);
        (account, state, input) = cur.unpackContext();
        (i, , ) = Cursors.decode(cur.state);
    }

    function testUnpackRecover(bytes calldata source)
        external
        pure
        returns (uint handler, uint resources, bytes32 key, bytes calldata witness, uint i)
    {
        Cur memory cur = Decoders.wrap(source);
        (handler, resources, key, witness) = cur.unpackRecover();
        (i, , ) = Cursors.decode(cur.state);
    }

    function testUnpackRelay(bytes calldata source)
        external
        pure
        returns (uint portal, uint resources, bytes calldata input, uint i)
    {
        Cur memory cur = Decoders.wrap(source);
        (portal, resources, input) = cur.unpackRelay();
        (i, , ) = Cursors.decode(cur.state);
    }

    function testUnpackDispatch(bytes calldata source)
        external
        pure
        returns (uint portal, uint resources, bytes calldata payload, uint i)
    {
        Cur memory cur = Decoders.wrap(source);
        (portal, resources, payload) = cur.unpackDispatch();
        (i, , ) = Cursors.decode(cur.state);
    }

}
