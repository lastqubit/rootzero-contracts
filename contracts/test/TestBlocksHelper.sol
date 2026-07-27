// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Blocks} from "../codec/Blocks.sol";
import {Buffers} from "../codec/Buffers.sol";
import {Sizes, Specs} from "../codec/Specs.sol";
import {Writer, Writers} from "../codec/Writers.sol";
import {Descriptors} from "../utils/Descriptors.sol";

using Writers for Writer;

contract TestBlocksHelper {
    bytes4 private constant TestKey = bytes4(uint32(1));

    function transactionSpec() external pure returns (bytes32) {
        return bytes32(Specs.Transaction);
    }

    function specRanges() external pure returns (uint32 fixedMin, uint32 fixedMax, uint32 dynamicMin, uint32 dynamicMax) {
        return (
            Specs.min(Specs.Transaction),
            Specs.max(Specs.Transaction),
            Specs.min(Specs.Step),
            Specs.max(Specs.Step)
        );
    }

    function listAssetDescriptor() external pure returns (bytes4 key, bytes4 item, uint8 groupSize) {
        uint input = Specs.derive(Specs.Asset, Specs.List, 3);
        uint descriptor = Descriptors.pack(Specs.Empty, input, Specs.Empty, false, false);
        return Descriptors.input(descriptor);
    }

    function balanceOutputDescriptor()
        external
        pure
        returns (uint spec)
    {
        uint descriptor = Descriptors.pack(Specs.Empty, Specs.Empty, Specs.Balance, false, false);
        return Descriptors.output(descriptor);
    }

    function groupedBalanceOutputDescriptor() external pure returns (uint spec, uint8 groupSize) {
        uint output = Specs.withGroup(Specs.Balance, 3);
        uint descriptor = Descriptors.pack(Specs.Empty, Specs.Empty, output, false, false);
        spec = Descriptors.output(descriptor);
        groupSize = Specs.group(spec);
    }

    function rejectLaneContainer(bool output) external pure returns (uint) {
        uint wrapped = Specs.withContainer(Specs.Balance, Specs.List);
        return output
            ? Descriptors.pack(Specs.Empty, Specs.Empty, wrapped, false, false)
            : Descriptors.pack(wrapped, Specs.Empty, Specs.Empty, false, false);
    }

    function lazyBalance(bytes32 asset, uint amount) external pure returns (bytes memory) {
        Writer memory writer = Writers.init(Specs.Balance, 1);
        writer.appendBalance(asset, amount);
        return writer.finish();
    }

    function emptyWriter() external pure returns (uint i, uint end, bool growable, uint length) {
        Writer memory writer = Writers.init(Specs.Bytes, 0);
        (i, end, growable) = Buffers.decode(writer.packed);
        length = writer.dst.length;
    }

    function rejectSecond32(bytes32 value) external pure returns (bytes memory) {
        uint spec = Specs.create(TestKey, 32, 32, 32);
        Writer memory writer = Writers.init(spec, 1);
        writer.appendBlock32(spec, value);
        writer.appendBlock32(spec, value);
        return writer.finish();
    }

    function rejectOversizedDynamic(bytes memory data) external pure returns (bytes memory) {
        uint spec = Specs.create(Specs.key(Specs.Bytes), 32, 32, 32);
        Writer memory writer = Writers.init(spec, 1);
        writer.appendBlock(spec, data);
        return writer.finish();
    }

    function rejectOutOfRange(bytes memory data) external pure returns (bytes memory) {
        uint spec = Specs.create(Specs.key(Specs.Bytes), 2, 4, 32);
        Writer memory writer = Writers.init(spec, 1);
        writer.appendBlock(spec, data);
        return writer.finish();
    }

    function grow(
        bytes memory buffer,
        uint written,
        uint required
    ) external pure returns (bytes memory) {
        return Buffers.grow(buffer, written, required);
    }

    function writeBalance(
        uint offset,
        bytes32 asset,
        uint amount
    ) external pure returns (bytes memory dst, uint next) {
        dst = new bytes(offset + Sizes.Balance);
        next = Blocks.writeBalance(dst, offset, asset, amount);
    }

    function writeTransaction(
        uint offset,
        bytes32 from,
        bytes32 to,
        bytes32 asset,
        uint amount
    ) external pure returns (bytes memory dst, uint next) {
        dst = new bytes(offset + Sizes.Transaction);
        next = Blocks.writeTransaction(dst, offset, from, to, asset, amount);
    }
}
