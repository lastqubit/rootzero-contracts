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

    function expectAbsolute(
        bytes calldata source,
        uint spec
    ) external pure returns (uint i, uint end) {
        uint abs = position(source);
        (i, end) = Blocks.expect(abs, spec);
        i -= abs;
        end -= abs;
    }

    function headerAbsolute(bytes calldata source) external pure returns (bytes4 key, uint len) {
        return Blocks.header(position(source));
    }

    function headerAbsolute(bytes calldata source, bytes4 key) external pure returns (uint len) {
        return Blocks.header(position(source), key);
    }

    function writeBalance(
        uint offset,
        bytes32 asset,
        uint amount
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.Balance);
        Blocks.writeBalance(dst, offset, asset, amount);
    }

    function writeList(uint offset, bytes memory value) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.Header + value.length);
        Blocks.writeList(dst, offset, value);
    }

    function writeEvm(uint offset, bytes memory value) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.Header + value.length);
        Blocks.writeEvm(dst, offset, value);
    }

    function writeBytes(uint offset, bytes memory value) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.Header + value.length);
        Blocks.writeBytes(dst, offset, value);
    }

    function writeString(uint offset, string memory value) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.Header + bytes(value).length);
        Blocks.writeString(dst, offset, value);
    }

    function writeStep(
        uint offset,
        uint target,
        uint resources,
        bytes memory request
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.B64 + Sizes.Header + request.length);
        Blocks.writeStep(dst, offset, target, resources, request);
    }

    function writeCall(
        uint offset,
        uint target,
        uint resources,
        bytes memory payload
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.B64 + Sizes.Header + payload.length);
        Blocks.writeCall(dst, offset, target, resources, payload);
    }

    function writeRelay(
        uint offset,
        uint portal,
        uint resources,
        bytes memory request
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.B64 + Sizes.Header + request.length);
        Blocks.writeRelay(dst, offset, portal, resources, request);
    }

    function writeDispatch(
        uint offset,
        uint portal,
        uint resources,
        bytes memory payload
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.B64 + Sizes.Header + payload.length);
        Blocks.writeDispatch(dst, offset, portal, resources, payload);
    }

    function writeContext(
        uint offset,
        bytes32 account,
        bytes memory state,
        bytes memory request
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.B32 + 2 * Sizes.Header + state.length + request.length);
        Blocks.writeContext(dst, offset, account, state, request);
    }

    function writeRecover(
        uint offset,
        uint handler,
        uint resources,
        bytes32 key,
        bytes memory witness
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.B96 + Sizes.Header + witness.length);
        Blocks.writeRecover(dst, offset, handler, resources, key, witness);
    }

    function writeLabel(
        uint offset,
        uint id,
        bytes32 namespace,
        string memory name
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.B64 + Sizes.Header + bytes(name).length);
        Blocks.writeLabel(dst, offset, id, namespace, name);
    }

    function writeSchema(
        uint offset,
        uint spec,
        string memory body,
        bytes32 name
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.B64 + Sizes.Header + bytes(body).length);
        Blocks.writeSchema(dst, offset, spec, body, name);
    }

    function position(bytes calldata source) private pure returns (uint abs) {
        assembly ("memory-safe") {
            abs := source.offset
        }
    }

    function unpackAccount(bytes calldata source) external pure returns (bytes32) {
        return Blocks.unpackAccount(position(source));
    }

    function unpackAsset(bytes calldata source) external pure returns (bytes32) {
        return Blocks.unpackAsset(position(source));
    }

    function unpackNode(bytes calldata source) external pure returns (uint) {
        return Blocks.unpackNode(position(source));
    }

    function unpackFee(bytes calldata source) external pure returns (uint) {
        return Blocks.unpackFee(position(source));
    }

    function unpackStatus(bytes calldata source) external pure returns (uint) {
        return Blocks.unpackStatus(position(source));
    }

    function unpackAmount(bytes calldata source) external pure returns (bytes32, uint) {
        return Blocks.unpackAmount(position(source));
    }

    function unpackBalance(bytes calldata source) external pure returns (bytes32, uint) {
        return Blocks.unpackBalance(position(source));
    }

    function unpackBounty(bytes calldata source) external pure returns (uint, bytes32) {
        return Blocks.unpackBounty(position(source));
    }

    function unpackAssetAmount(bytes calldata source) external pure returns (bytes32, uint) {
        return Blocks.unpackAssetAmount(position(source));
    }

    function unpackAccountAsset(bytes calldata source) external pure returns (bytes32, bytes32) {
        return Blocks.unpackAccountAsset(position(source));
    }

    function unpackBalanceLimit(bytes calldata source) external pure returns (bytes32, uint, uint) {
        return Blocks.unpackBalanceLimit(position(source));
    }

    function unpackAllocation(bytes calldata source) external pure returns (uint, bytes32, uint) {
        return Blocks.unpackAllocation(position(source));
    }

    function unpackAllowance(bytes calldata source) external pure returns (uint, bytes32, uint) {
        return Blocks.unpackAllowance(position(source));
    }

    function unpackCustody(bytes calldata source) external pure returns (uint, bytes32, uint) {
        return Blocks.unpackCustody(position(source));
    }

    function unpackAccountAmount(bytes calldata source) external pure returns (bytes32, bytes32, uint) {
        return Blocks.unpackAccountAmount(position(source));
    }

    function unpackHostAmount(bytes calldata source) external pure returns (uint, bytes32, uint) {
        return Blocks.unpackHostAmount(position(source));
    }

    function unpackHostAccountAsset(bytes calldata source) external pure returns (uint, bytes32, bytes32) {
        return Blocks.unpackHostAccountAsset(position(source));
    }

    function unpackCustodyLimit(bytes calldata source) external pure returns (uint, bytes32, uint, uint) {
        return Blocks.unpackCustodyLimit(position(source));
    }

    function unpackTransaction(
        bytes calldata source
    ) external pure returns (bytes32, bytes32, bytes32, uint) {
        return Blocks.unpackTransaction(position(source));
    }

    function unpackHostAccountAmount(
        bytes calldata source
    ) external pure returns (uint, bytes32, bytes32, uint) {
        return Blocks.unpackHostAccountAmount(position(source));
    }

    function unpackList(bytes calldata source) external pure returns (bytes memory data, uint length) {
        uint abs = position(source);
        bytes calldata value;
        uint next;
        (value, next) = Blocks.unpackList(abs);
        data = value;
        length = next - abs;
    }

    function unpackEvm(bytes calldata source) external pure returns (bytes memory data, uint length) {
        uint abs = position(source);
        bytes calldata value;
        uint next;
        (value, next) = Blocks.unpackEvm(abs);
        data = value;
        length = next - abs;
    }

    function unpackBytes(bytes calldata source) external pure returns (bytes memory data, uint length) {
        uint abs = position(source);
        bytes calldata value;
        uint next;
        (value, next) = Blocks.unpackBytes(abs);
        data = value;
        length = next - abs;
    }

    function unpackString(bytes calldata source) external pure returns (bytes memory data, uint length) {
        uint abs = position(source);
        bytes calldata value;
        uint next;
        (value, next) = Blocks.unpackString(abs);
        data = value;
        length = next - abs;
    }

    function writeTransaction(
        uint offset,
        bytes32 from,
        bytes32 to,
        bytes32 asset,
        uint amount
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.Transaction);
        Blocks.writeTransaction(dst, offset, from, to, asset, amount);
    }
}
