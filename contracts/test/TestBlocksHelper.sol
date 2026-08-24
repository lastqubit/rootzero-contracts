// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {Blocks} from "../codec/Blocks.sol";
import {Buffers} from "../codec/Buffers.sol";
import {Sizes, Specs} from "../codec/Specs.sol";
import {Writer, Writers} from "../codec/Writers.sol";
import {Execution, Executions, Lanes} from "../execution/Execution.sol";
import {Cursors, Cur} from "../utils/Cursors.sol";
import {Descriptors, Flags} from "../codec/Descriptors.sol";
import {Budget, Budgets} from "../execution/Budget.sol";
import {Action} from "../annotations/Action.sol";

using Writers for Writer;
using Budgets for Budget;

contract TestBlocksHelper is Action {
    bytes4 private constant TestKey = bytes4(uint32(1));

    function transactionSpec() external pure returns (bytes32) {
        return bytes32(Specs.Transaction);
    }

    function specRanges() external pure returns (uint32 fixedMin, uint32 fixedMax, uint32 dynamicMin, uint32 dynamicMax) {
        (, fixedMin, fixedMax) = Specs.decode(Specs.Transaction);
        (, dynamicMin, dynamicMax) = Specs.decode(Specs.Step);
    }

    function specHint(uint32 hint) external pure returns (uint24) {
        (uint capacity, ) = Specs.allocation(Specs.create(TestKey, 0, 0, hint), 1);
        return uint24(capacity - Sizes.Header);
    }

    function exactSpec(uint32 key, uint32 size) external pure returns (uint) {
        return Specs.create(key, size);
    }

    function publishAction(uint entity, uint value) external {
        action(entity, value);
    }

    function groupedCapacity() external pure returns (uint) {
        (uint capacity, ) = Specs.allocation(Specs.group(Specs.Balance, 3), 2);
        return capacity;
    }

    function balanceOutputDescriptor()
        external
        pure
        returns (uint spec)
    {
        uint descriptor = Descriptors.create(Specs.Empty, Specs.Empty, Specs.Balance, 0, 0);
        return uint(uint128(descriptor >> 48)) << 128;
    }

    function groupedBalanceOutputDescriptor() external pure returns (uint spec, uint stride) {
        uint output = Specs.group(Specs.Balance, 3);
        uint descriptor = Descriptors.create(Specs.Empty, Specs.Empty, output, 0, 0);
        spec = uint(uint128(descriptor >> 48)) << 128;
        stride = Specs.count(spec, 1);
    }

    function descriptorFlags() external pure returns (bool funded, bool admin) {
        uint8 flags = Flags.AdminFunded;
        uint descriptor = Descriptors.create(Specs.Empty, Specs.Empty, Specs.Empty, 0, flags);
        funded = Descriptors.flagged(descriptor, Flags.Funded);
        admin = Descriptors.flagged(descriptor, Flags.Admin);
    }

    function descriptorTransactions() external pure returns (uint8) {
        uint descriptor = Descriptors.create(Specs.Empty, Specs.Empty, Specs.Empty, 3, 0);
        return Descriptors.stride(descriptor, Lanes.Transactions);
    }

    function descriptorKey(uint8 lane) external pure returns (bytes4) {
        uint descriptor = Descriptors.create(
            Specs.Balance,
            Specs.Asset,
            Specs.Amount,
            1,
            0
        );
        return Descriptors.key(descriptor, lane);
    }

    /// @notice Return the allocation derived for a constructed descriptor lane.
    function descriptorAllocation(
        uint output,
        uint8 transactions,
        uint8 lane,
        uint groups
    ) external pure returns (uint capacity, bool growable) {
        uint descriptor = Descriptors.create(Specs.Empty, Specs.Empty, output, transactions, 0);
        return Descriptors.allocation(descriptor, lane, groups);
    }

    function executionTransactions(
        uint8 count,
        uint batches,
        uint writes
    ) external view returns (bytes memory transactions) {
        uint descriptor = Descriptors.create(Specs.Empty, Specs.Empty, Specs.Empty, count, 0);
        Execution memory exec = Executions.openInput(msg.data[0:0], descriptor, batches);
        for (uint i; i < writes; ++i) {
            Executions.queueTransaction(exec, 0, 0, 0, i);
        }
        transactions = Executions.finishTransactions(exec);
    }

    function executionOutputPosition(
        bytes32 asset,
        uint amount,
        bytes32 liability,
        uint debt
    ) external view returns (bytes memory output) {
        uint descriptor = Descriptors.create(Specs.Empty, Specs.Empty, Specs.Position, 0, 0);
        Execution memory exec = Executions.openInput(msg.data[0:0], descriptor, 1);
        Executions.outputPosition(exec, asset, amount, liability, debt);
        output = Executions.finish(exec);
    }

    function executionOutputDebt(
        bytes32 liability,
        uint debt
    ) external view returns (bytes memory output) {
        uint descriptor = Descriptors.create(Specs.Empty, Specs.Empty, Specs.Debt, 0, 0);
        Execution memory exec = Executions.openInput(msg.data[0:0], descriptor, 1);
        Executions.outputDebt(exec, liability, debt);
        output = Executions.finish(exec);
    }

    function executionOutputEmpty(bytes4 key) external view returns (bytes memory output) {
        uint descriptor = Descriptors.create(Specs.Empty, Specs.Empty, Specs.Balance, 0, 0);
        Execution memory exec = Executions.openInput(msg.data[0:0], descriptor, 1);
        Executions.outputEmpty(exec, key);
        output = Executions.finish(exec);
    }

    function executionOutputHostAsset(uint host, bytes32 asset) external view returns (bytes memory output) {
        uint descriptor = Descriptors.create(Specs.Empty, Specs.Empty, Specs.HostAsset, 0, 0);
        Execution memory exec = Executions.openInput(msg.data[0:0], descriptor, 1);
        Executions.outputHostAsset(exec, host, asset);
        output = Executions.finish(exec);
    }

    function executionUnpackPosition(
        bytes calldata state
    ) external view returns (bytes32 asset, uint amount, bytes32 liability, uint debt) {
        uint descriptor = Descriptors.create(Specs.Position, Specs.Empty, Specs.Empty, 0, 0);
        Execution memory exec = Executions.openState(state, descriptor, 1);
        return Executions.unpackPosition(exec, Lanes.State);
    }

    function executionUnpackDebt(
        bytes calldata state
    ) external view returns (bytes32 liability, uint debt) {
        uint descriptor = Descriptors.create(Specs.Debt, Specs.Empty, Specs.Empty, 0, 0);
        Execution memory exec = Executions.openState(state, descriptor, 1);
        return Executions.unpackDebt(exec, Lanes.State);
    }

    function executionIsEmpty(bytes calldata input, uint spec, bytes4 key) external view returns (bool) {
        uint descriptor = Descriptors.create(Specs.Empty, spec, Specs.Empty, 0, 0);
        Execution memory exec = Executions.openInput(input, descriptor, 1);
        return Executions.isEmpty(exec, Lanes.Input, key);
    }

    function executionTryConsumeEmpty(
        bytes calldata input,
        uint spec,
        bytes4 key
    ) external view returns (bool empty, bool more) {
        uint descriptor = Descriptors.create(Specs.Empty, spec, Specs.Empty, 0, 0);
        Execution memory exec = Executions.openInput(input, descriptor, 1);
        empty = Executions.tryConsumeEmpty(exec, Lanes.Input, key);
        return (empty, Executions.more(exec));
    }

    function executionEnterAmount(
        bytes calldata state,
        bytes calldata input
    ) external view returns (bytes32 stateAsset, uint stateAmount, bytes32 inputAsset, uint inputAmount) {
        uint descriptor = Descriptors.create(Specs.Balance, Specs.List, Specs.Empty, 0, 0);
        Execution memory exec = Executions.open(state, input, descriptor, 1);
        (, uint end) = Executions.enter(exec, Lanes.Input, Specs.List);
        (stateAsset, stateAmount) = Executions.unpackBalance(exec, Lanes.State);
        (inputAsset, inputAmount) = Executions.unpackAmount(exec, Lanes.Input);
        Executions.expectAbs(exec, end);
    }

    function executionList(bytes calldata input, uint spec) external view returns (uint itemsLen, bool complete) {
        uint descriptor = Descriptors.create(Specs.Empty, spec, Specs.Empty, 0, 0);
        Execution memory exec = Executions.openInput(input, descriptor, 1);
        Cur memory items = Executions.list(exec, spec, Lanes.Input);
        (, , itemsLen) = Cursors.decode(items.state);
        complete = !Executions.more(exec);
    }

    function executionTakeBlock(
        bytes calldata state,
        bytes calldata input,
        bytes4 inputKey,
        bytes4 expectedKey
    ) external view returns (bytes calldata data, bytes32 asset, uint amount, bool complete) {
        uint inputSpec = Specs.create(inputKey, 0, 0, 0);
        uint descriptor = Descriptors.create(Specs.Balance, inputSpec, Specs.Empty, 0, 0);
        Execution memory exec = Executions.open(state, input, descriptor, 1);
        data = Executions.takeBlock(exec, Lanes.Input, expectedKey);
        (asset, amount) = Executions.unpackBalance(exec, Lanes.State);
        complete = !Executions.more(exec);
    }

    function executionRaw(
        bytes calldata state,
        bytes calldata input
    ) external view returns (bytes calldata beforeState, bytes calldata afterState, bytes calldata rawInput) {
        uint descriptor = Descriptors.create(Specs.Balance, Specs.Amount, Specs.Empty, 0, 0);
        Execution memory exec = Executions.open(state, input, descriptor, 1);
        beforeState = Executions.rawState(exec);
        Executions.unpackBalance(exec, Lanes.State);
        afterState = Executions.rawState(exec);
        rawInput = Executions.rawInput(exec);
    }

    function executionRawEmptyState(
        bytes calldata input
    ) external view returns (bytes calldata state) {
        uint descriptor = Descriptors.create(Specs.Empty, Specs.Amount, Specs.Empty, 0, 0);
        Execution memory exec = Executions.openInput(input, descriptor, 1);
        return Executions.rawState(exec);
    }

    function executionEnterWords(bytes calldata input) external view returns (bytes32 first, bytes32 second) {
        uint descriptor = Descriptors.create(Specs.Empty, Specs.List, Specs.Empty, 0, 0);
        Execution memory exec = Executions.openInput(input, descriptor, 1);
        (, uint end) = Executions.enter(exec, Lanes.Input, Specs.List);
        first = Executions.next32(exec, Lanes.Input);
        second = Executions.next32(exec, Lanes.Input);
        Executions.expectAbs(exec, end);
    }

    function executionAdvance(
        bytes calldata input,
        uint amount
    ) external view returns (uint abs, bytes32 value, bool complete) {
        uint offset;
        assembly ("memory-safe") {
            offset := input.offset
        }

        uint descriptor = Descriptors.create(Specs.Empty, Specs.List, Specs.Empty, 0, 0);
        Execution memory exec = Executions.openInput(input, descriptor, 1);
        (, uint end) = Executions.enter(exec, Lanes.Input, Specs.List);
        abs = Executions.absolute(exec, Lanes.Input);
        Executions.advance(exec, Lanes.Input, amount);
        value = Blocks.read32(abs);
        complete = amount == end - abs;
        return (abs - offset, value, complete);
    }

    function executionTake(
        bytes calldata input,
        uint amount
    ) external view returns (uint abs, bytes32 value, bool complete) {
        uint offset;
        assembly ("memory-safe") {
            offset := input.offset
        }

        uint descriptor = Descriptors.create(Specs.Empty, Specs.List, Specs.Empty, 0, 0);
        Execution memory exec = Executions.openInput(input, descriptor, 1);
        (, uint end) = Executions.enter(exec, Lanes.Input, Specs.List);
        abs = Executions.take(exec, Lanes.Input, amount);
        value = Blocks.read32(abs);
        complete = amount == end - abs;
        return (abs - offset, value, complete);
    }

    function executionEnterSized(bytes calldata input)
        external
        view
        returns (bytes1 a, bytes2 b, bytes4 c, bytes8 d, bytes16 e, bytes32 f)
    {
        uint descriptor = Descriptors.create(Specs.Empty, Specs.List, Specs.Empty, 0, 0);
        Execution memory exec = Executions.openInput(input, descriptor, 1);
        (, uint end) = Executions.enter(exec, Lanes.Input, Specs.List);
        a = Executions.next1(exec, Lanes.Input);
        b = Executions.next2(exec, Lanes.Input);
        c = Executions.next4(exec, Lanes.Input);
        d = Executions.next8(exec, Lanes.Input);
        e = Executions.next16(exec, Lanes.Input);
        f = Executions.next32(exec, Lanes.Input);
        Executions.expectAbs(exec, end);
    }

    function writerCopies(bytes calldata value) external pure returns (bytes memory) {
        Writer memory writer = Writers.init(0, true);
        writer.copyBlock(Specs.create(TestKey, 0, 0, 0), value);
        writer.copyList(value);
        writer.copyEvm(value);
        writer.copyBytes(value);
        writer.copyStep(1, 2, value);
        writer.copyCall(3, 4, value);
        writer.copyRelay(5, 6, value);
        writer.copyDispatch(7, 8, value);
        writer.copyContext(bytes32(uint(9)), value, value);
        writer.copyRecover(10, 11, bytes32(uint(12)), value);
        return writer.finish();
    }

    function writerCopy(bytes calldata value) external pure returns (bytes memory) {
        Writer memory writer = Writers.init(0, true);
        writer.append32(bytes32(uint(0xaa) << 248), 1);
        writer.copy(value);
        writer.append32(bytes32(uint(0xbb) << 248), 1);
        return writer.finish();
    }

    function stringCopies(
        string calldata value
    ) external view returns (bytes memory factory, bytes memory written, bytes memory output) {
        factory = Blocks.createStringCopy(value);

        Writer memory writer = Writers.init(Specs.String, 1);
        writer.copyString(value);
        written = writer.finish();

        uint descriptor = Descriptors.create(Specs.Empty, Specs.Empty, Specs.String, 0, 0);
        Execution memory exec = Executions.openInput(msg.data[0:0], descriptor, 1);
        Executions.outputCopyString(exec, value);
        output = Executions.finish(exec);
    }

    function bufferCopy(
        uint capacity,
        uint offset,
        bytes calldata value
    ) external pure returns (bytes memory buffer, uint next) {
        buffer = new bytes(capacity);
        next = Buffers.copy(buffer, offset, value);
    }

    function factoryCopies(bytes calldata value) external pure returns (bytes memory) {
        bytes memory leaves = bytes.concat(
            Blocks.createCopy(TestKey, value),
            Blocks.createListCopy(value),
            Blocks.createEvmCopy(value),
            Blocks.createBytesCopy(value)
        );
        bytes memory composites = bytes.concat(
            Blocks.createStepCopy(1, 2, value),
            Blocks.createCallCopy(3, 4, value),
            Blocks.createRelayCopy(5, 6, value),
            Blocks.createDispatchCopy(7, 8, value)
        );
        return bytes.concat(
            leaves,
            composites,
            Blocks.createContextCopy(bytes32(uint(9)), value, value),
            Blocks.createRecoverCopy(10, 11, bytes32(uint(12)), value)
        );
    }

    function executionCopies(bytes calldata value) external view returns (bytes memory) {
        uint descriptor = Descriptors.create(Specs.Empty, Specs.Empty, Specs.Bytes, 0, 0);
        Execution memory exec = Executions.openInput(msg.data[0:0], descriptor, 1);
        Executions.outputCopyBlock(exec, Specs.create(TestKey, 0, 0, 0), value);
        Executions.outputCopyList(exec, value);
        Executions.outputCopyEvm(exec, value);
        Executions.outputCopyBytes(exec, value);
        Executions.outputCopyStep(exec, 1, 2, value);
        Executions.outputCopyCall(exec, 3, 4, value);
        Executions.outputCopyRelay(exec, 5, 6, value);
        Executions.outputCopyDispatch(exec, 7, 8, value);
        Executions.outputCopyContext(exec, bytes32(uint(9)), value, value);
        Executions.outputCopyRecover(exec, 10, 11, bytes32(uint(12)), value);
        return Executions.finish(exec);
    }

    function lazyBalance(bytes32 asset, uint amount) external pure returns (bytes memory) {
        Writer memory writer = Writers.init(Specs.Balance, 1);
        writer.appendBalance(asset, amount);
        return writer.finish();
    }

    function appendHostAsset(uint host, bytes32 asset) external pure returns (bytes memory) {
        Writer memory writer = Writers.init(Specs.HostAsset, 1);
        writer.appendHostAsset(host, asset);
        return writer.finish();
    }

    function writeHostAsset(uint offset, uint host, bytes32 asset) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.HostAsset);
        Blocks.writeHostAsset(dst, offset, host, asset);
    }

    function emptyWriter() external pure returns (uint i, uint len, bool growable, uint length) {
        Writer memory writer = Writers.init(Specs.Bytes, 0);
        (i, , len) = Cursors.decode(writer.cur);
        growable = Cursors.flagged(writer.cur, Buffers.Growable);
        length = writer.dst.length;
    }

    /// @notice Reserve a lazily allocated buffer and expose its resulting metadata.
    function reserveBuffer(
        uint len,
        uint count,
        bool growable,
        uint8 tag,
        uint advance,
        uint touch
    ) external pure returns (uint i, uint next, uint capacity, uint packedCount, uint8 flags, uint8 packedtag, uint physical) {
        uint cur = Buffers.cursor(len, count, growable, tag);
        bytes memory buffer;
        (cur, buffer, i) = Buffers.reserve(cur, buffer, advance, touch);
        (next, , capacity) = Cursors.decode(cur);
        (packedCount, flags, packedtag) = Cursors.meta(cur);
        physical = buffer.length;
    }

    /// @notice Grow a buffer across two writes and return its finalized bytes.
    function growBuffer(bytes32 a, bytes32 b) external pure returns (bytes memory buffer) {
        uint cur = Buffers.cursor(32, 1, true, 0);
        uint i;
        (cur, buffer, i) = Buffers.reserve(cur, buffer, 32, 32);
        Buffers.write32(buffer, i, a);
        (cur, buffer, i) = Buffers.reserve(cur, buffer, 32, 32);
        Buffers.write32(buffer, i, b);
        return Buffers.finish(cur, buffer);
    }

    /// @notice Spend the value lane of `resources` and drain the remainder.
    function budgetUseResourceValue(uint resources) external payable returns (uint value, uint remaining) {
        Budget memory budget = Budgets.open();
        value = budget.useResourceValue(resources);
        remaining = budget.drain();
    }

    /// @notice Spend an exact value and drain the remainder.
    function budgetUseValue(uint value) external payable returns (uint used, uint remaining) {
        Budget memory budget = Budgets.open();
        used = budget.useValue(value);
        remaining = budget.drain();
    }

    /// @notice Drain a standalone budget and expose its cleared state.
    function budgetDrain() external payable returns (uint drained, uint remaining) {
        Budget memory budget = Budgets.open();
        drained = budget.drain();
        remaining = budget.remaining;
    }

    /// @notice Detach an execution budget and expose both resulting balances.
    function takeBudget() external payable returns (uint execution, uint detached) {
        Execution memory exec = Executions.open();
        Budget memory budget = Executions.takeBudget(exec);
        execution = exec.budget;
        detached = budget.remaining;
    }

    /// @notice Drain an execution budget and expose both resulting values.
    function drainBudget() external payable returns (uint execution, uint drained) {
        Execution memory exec = Executions.open();
        drained = Executions.drainBudget(exec);
        execution = exec.budget;
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

    function read32(bytes calldata source, uint i) external pure returns (bytes32) {
        return Blocks.read32(position(source) + i);
    }

    function readWidths(
        bytes calldata source,
        uint i
    ) external pure returns (bytes1, bytes2, bytes4, bytes8, bytes16, bytes32) {
        uint abs = position(source) + i;
        return (
            Blocks.read1(abs),
            Blocks.read2(abs),
            Blocks.read4(abs),
            Blocks.read8(abs),
            Blocks.read16(abs),
            Blocks.read32(abs)
        );
    }

    function requireWidth(bytes calldata source, uint i, uint width, bytes32 expected) external pure {
        uint abs = position(source) + i;
        if (width == 1) {
            Blocks.require1(abs, bytes1(expected));
            return;
        }
        if (width == 2) {
            Blocks.require2(abs, bytes2(expected));
            return;
        }
        if (width == 4) {
            Blocks.require4(abs, bytes4(expected));
            return;
        }
        if (width == 8) {
            Blocks.require8(abs, bytes8(expected));
            return;
        }
        if (width == 16) {
            Blocks.require16(abs, bytes16(expected));
            return;
        }
        if (width == 32) {
            Blocks.require32(abs, expected);
            return;
        }
        revert Blocks.UnexpectedValue();
    }

    function read32AsUint(bytes calldata source, uint i) external pure returns (uint) {
        return uint(Blocks.read32(position(source) + i));
    }

    function expectAbsolute(
        bytes calldata source,
        uint spec
    ) external pure returns (uint i, uint end) {
        uint head = position(source);
        (uint abs, uint limit) = Blocks.expect(head, spec);
        i = abs - head;
        end = limit - head;
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

    function writeDebt(
        uint offset,
        bytes32 liability,
        uint debt
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.Debt);
        Blocks.writeDebt(dst, offset, liability, debt);
    }

    function writePosition(
        uint offset,
        bytes32 asset,
        uint amount,
        bytes32 liability,
        uint debt
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.Position);
        Blocks.writePosition(dst, offset, asset, amount, liability, debt);
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
        uint cmd,
        uint resources,
        bytes memory input
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.B64 + Sizes.Header + input.length);
        Blocks.writeStep(dst, offset, cmd, resources, input);
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
        bytes memory input
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.B64 + Sizes.Header + input.length);
        Blocks.writeRelay(dst, offset, portal, resources, input);
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
        bytes memory input
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.B32 + 2 * Sizes.Header + state.length + input.length);
        Blocks.writeContext(dst, offset, account, state, input);
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
        bytes32 namespace,
        string memory name
    ) external pure returns (bytes memory dst) {
        dst = new bytes(offset + Sizes.B32 + Sizes.Header + bytes(name).length);
        Blocks.writeLabel(dst, offset, namespace, name);
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

    function unpackStatus(bytes calldata source) external pure returns (uint) {
        return Blocks.unpackStatus(position(source));
    }

    function unpackAmount(bytes calldata source) external pure returns (bytes32, uint) {
        return Blocks.unpackAmount(position(source));
    }

    function unpackBalance(bytes calldata source) external pure returns (bytes32, uint) {
        return Blocks.unpackBalance(position(source));
    }

    function unpackDebt(bytes calldata source) external pure returns (bytes32, uint) {
        return Blocks.unpackDebt(position(source));
    }

    function unpackPosition(bytes calldata source) external pure returns (bytes32, uint, bytes32, uint) {
        return Blocks.unpackPosition(position(source));
    }

    function unpackAccountAsset(bytes calldata source) external pure returns (bytes32, bytes32) {
        return Blocks.unpackAccountAsset(position(source));
    }

    function unpackHostAsset(bytes calldata source) external pure returns (uint, bytes32) {
        return Blocks.unpackHostAsset(position(source));
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
        uint end;
        (value, end) = Blocks.unpackList(abs);
        data = value;
        length = end - abs;
    }

    function unpackEvm(bytes calldata source) external pure returns (bytes memory data, uint length) {
        uint abs = position(source);
        bytes calldata value;
        uint end;
        (value, end) = Blocks.unpackEvm(abs);
        data = value;
        length = end - abs;
    }

    function unpackBytes(bytes calldata source) external pure returns (bytes memory data, uint length) {
        uint abs = position(source);
        bytes calldata value;
        uint end;
        (value, end) = Blocks.unpackBytes(abs);
        data = value;
        length = end - abs;
    }

    function unpackString(bytes calldata source) external pure returns (bytes memory data, uint length) {
        uint abs = position(source);
        bytes calldata value;
        uint end;
        (value, end) = Blocks.unpackString(abs);
        data = value;
        length = end - abs;
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
