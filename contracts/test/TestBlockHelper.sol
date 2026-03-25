// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AssetAmount, HostAmount, Tx, BlockRef, DataRef, MemRef, Writer, BALANCE_KEY, CUSTODY_KEY, TX_KEY, AMOUNT_KEY, BOUNTY_KEY, RECIPIENT_KEY, NODE_KEY, FUNDING_KEY, ASSET_KEY, ALLOCATION_KEY, STEP_KEY, QUANTITY_KEY} from "../blocks/Schema.sol";
import {Blocks} from "../blocks/Readers.sol";
import {Data} from "../blocks/Data.sol";
import {Mem} from "../blocks/Mem.sol";
import {InvalidBlock, MalformedBlocks, UnexpectedAsset, UnexpectedHost, UnexpectedMeta, ZeroRecipient, ZeroNode} from "../blocks/Errors.sol";
import {Writers, BALANCE_BLOCK_LEN, CUSTODY_BLOCK_LEN, TX_BLOCK_LEN} from "../blocks/Writers.sol";

using Blocks for BlockRef;
using Data for DataRef;
using Writers for Writer;
using Mem for MemRef;

contract TestBlockHelper {
    // ── Writers ──────────────────────────────────────────────────────────────

    function testBlockHeader(bytes4 key, uint selfLen, uint totalLen) external pure returns (uint) {
        return Writers.toBlockHeader(key, selfLen, totalLen);
    }

    function testWriteBalanceBlock(bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(BALANCE_BLOCK_LEN);
        w.appendBalance(asset, meta, amount);
        return w.dst;
    }

    function testWriteTwoBalanceBlocks(
        bytes32 a1, bytes32 m1, uint v1,
        bytes32 a2, bytes32 m2, uint v2
    ) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(BALANCE_BLOCK_LEN * 2);
        w.appendBalance(a1, m1, v1);
        w.appendBalance(a2, m2, v2);
        return w.dst;
    }

    function testWriteCustodyBlock(uint host_, bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(CUSTODY_BLOCK_LEN);
        w.appendCustody(host_, asset, meta, amount);
        return w.dst;
    }

    function testWriteTxBlock(bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(TX_BLOCK_LEN);
        w.appendTx(Tx({from: from_, to: to_, asset: asset, meta: meta, amount: amount}));
        return w.dst;
    }

    function testWriterDone() external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(BALANCE_BLOCK_LEN);
        // Don't write anything — done() should revert
        return Writers.done(w);
    }

    function testWriterFinish(bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
        Writer memory w = Writers.alloc(BALANCE_BLOCK_LEN * 2);
        w.appendBalance(asset, meta, amount);
        return Writers.finish(w);
    }

    // ── Blocks (calldata) ────────────────────────────────────────────────────

    function testParseBlock(bytes calldata source, uint i)
        external pure returns (bytes4 key, uint bound, uint end)
    {
        BlockRef memory ref = Blocks.from(source, i);
        return (ref.key, ref.bound, ref.end);
    }

    function testUnpackAmount(bytes calldata source, uint i)
        external pure returns (bytes32 asset, bytes32 meta, uint amount)
    {
        BlockRef memory ref = Blocks.amountFrom(source, i);
        return ref.unpackAmount(source);
    }

    function testUnpackBalance(bytes calldata source, uint i)
        external pure returns (bytes32 asset, bytes32 meta, uint amount)
    {
        BlockRef memory ref = Blocks.balanceFrom(source, i);
        return ref.unpackBalance(source);
    }

    function testUnpackCustody(bytes calldata source, uint i)
        external pure returns (uint host_, bytes32 asset, bytes32 meta, uint amount)
    {
        BlockRef memory ref = Blocks.custodyFrom(source, i);
        HostAmount memory v = ref.toCustodyValue(source);
        return (v.host, v.asset, v.meta, v.amount);
    }

    function testUnpackRecipient(bytes calldata source, uint i)
        external pure returns (bytes32 account)
    {
        BlockRef memory ref = Blocks.from(source, i);
        return ref.unpackRecipient(source);
    }

    function testUnpackNode(bytes calldata source, uint i)
        external pure returns (uint id)
    {
        BlockRef memory ref = Blocks.from(source, i);
        return ref.unpackNode(source);
    }

    function testUnpackQuantity(bytes calldata source, uint i)
        external pure returns (uint amount)
    {
        BlockRef memory ref = Blocks.quantityFrom(source, i);
        return ref.unpackQuantity(source);
    }

    function testExpectMinimum(bytes calldata source, uint i, bytes32 asset, bytes32 meta)
        external pure returns (uint amount)
    {
        (DataRef memory ref, ) = Data.from(source, i);
        return ref.expectMinimum(asset, meta);
    }

    function testExpectAmount(bytes calldata source, uint i, bytes32 asset, bytes32 meta)
        external pure returns (uint amount)
    {
        (DataRef memory ref, ) = Data.from(source, i);
        return ref.expectAmount(asset, meta);
    }

    function testExpectBalance(bytes calldata source, uint i, bytes32 asset, bytes32 meta)
        external pure returns (uint amount)
    {
        (DataRef memory ref, ) = Data.from(source, i);
        return ref.expectBalance(asset, meta);
    }

    function testExpectMaximum(bytes calldata source, uint i, bytes32 asset, bytes32 meta)
        external pure returns (uint amount)
    {
        (DataRef memory ref, ) = Data.from(source, i);
        return ref.expectMaximum(asset, meta);
    }

    function testExpectCustody(bytes calldata source, uint i, uint host_)
        external pure returns (bytes32 asset, bytes32 meta, uint amount)
    {
        (DataRef memory ref, ) = Data.from(source, i);
        AssetAmount memory value = ref.expectCustody(host_);
        return (value.asset, value.meta, value.amount);
    }

    function testUnpackFunding(bytes calldata source, uint i)
        external pure returns (uint host_, uint amount)
    {
        BlockRef memory ref = Blocks.from(source, i);
        return ref.unpackFunding(source);
    }

    function testUnpackAsset(bytes calldata source, uint i)
        external pure returns (bytes32 asset, bytes32 meta)
    {
        BlockRef memory ref = Blocks.from(source, i);
        return ref.unpackAsset(source);
    }

    function testUnpackAllocation(bytes calldata source, uint i)
        external pure returns (uint host_, bytes32 asset, bytes32 meta, uint amount)
    {
        BlockRef memory ref = Blocks.from(source, i);
        HostAmount memory v = ref.toAllocationValue(source);
        return (v.host, v.asset, v.meta, v.amount);
    }

    function testToTxValue(bytes calldata source, uint i)
        external pure returns (bytes32 from_, bytes32 to_, bytes32 asset, bytes32 meta, uint amount)
    {
        BlockRef memory ref = Blocks.from(source, i);
        Tx memory t = ref.toTxValue(source);
        return (t.from, t.to, t.asset, t.meta, t.amount);
    }

    function testCountBlocks(bytes calldata source, uint i, bytes4 key)
        external pure returns (uint count, uint next)
    {
        return Blocks.count(source, i, key);
    }

    function testResolveRecipient(bytes calldata source, uint i, uint limit, bytes32 backup)
        external pure returns (bytes32)
    {
        return Blocks.resolveRecipient(source, i, limit, backup);
    }

    function testResolveNode(bytes calldata source, uint i, uint limit, uint backup)
        external pure returns (uint)
    {
        return Blocks.resolveNode(source, i, limit, backup);
    }

    function testCreate32(bytes4 key, bytes32 value) external pure returns (bytes memory) {
        return Blocks.create32(key, value);
    }

    function testCreate64(bytes4 key, bytes32 a, bytes32 b) external pure returns (bytes memory) {
        return Blocks.create64(key, a, b);
    }

    function testCreate96(bytes4 key, bytes32 a, bytes32 b, bytes32 c) external pure returns (bytes memory) {
        return Blocks.create96(key, a, b, c);
    }

    function testCreate128(bytes4 key, bytes32 a, bytes32 b, bytes32 c, bytes32 d) external pure returns (bytes memory) {
        return Blocks.create128(key, a, b, c, d);
    }

    function testToBounty(uint amount, bytes32 relayer) external pure returns (bytes memory) {
        return Blocks.toBountyBlock(amount, relayer);
    }

    function testToCustody(uint host_, bytes32 asset, bytes32 meta, uint amount) external pure returns (bytes memory) {
        return Blocks.toCustodyBlock(host_, asset, meta, amount);
    }

    // ── Mem (memory) ─────────────────────────────────────────────────────────

    function testMemParseBalance(bytes memory source, uint i)
        external pure returns (bytes32 asset, bytes32 meta, uint amount)
    {
        MemRef memory ref = Mem.from(source, i);
        return ref.unpackBalance(source);
    }

    function testMemParseCustody(bytes memory source, uint i)
        external pure returns (HostAmount memory value)
    {
        MemRef memory ref = Mem.from(source, i);
        return ref.toCustodyValue(source);
    }

    function testMemSlice(bytes memory source, uint start, uint end_)
        external pure returns (bytes memory)
    {
        return Mem.slice(source, start, end_);
    }

    function testMemCount(bytes memory source, uint i, bytes4 key)
        external pure returns (uint count, uint next)
    {
        return Mem.count(source, i, key);
    }

    function testAllocBalancesFromCount(bytes calldata source, uint i, bytes4 sourceKey)
        external pure returns (uint count, uint next)
    {
        return Blocks.count(source, i, sourceKey);
    }
}
