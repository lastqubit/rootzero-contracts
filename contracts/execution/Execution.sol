// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {HostAmount} from "../core/Types.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Buffers} from "../codec/Buffers.sol";
import {Cursors} from "../codec/Cursors.sol";
import {Sizes, Specs} from "../codec/Specs.sol";
import {Descriptors} from "../utils/Descriptors.sol";
import {Spans} from "../utils/Spans.sol";

/// @notice Mutable state shared across one endpoint execution.
/// @dev `cursors` contains tagged input and state lanes. Cursor operations
/// select one logical lane by swapping it into the lower 128 bits.
struct Execution {
    uint budget;
    uint cursors;
    /// @dev Packed writer metadata; currently output-only, with transactions planned as another lane.
    uint writers;
    bytes transactions;
    bytes output;
}

/// @notice Conventional cursor tags used by an execution.
library Lanes {
    uint8 internal constant Input = 0;
    uint8 internal constant State = 1;
}

library Executions {
    /// @dev Thrown when an execution attempts to spend more value than remains in its budget.
    error InsufficientValue();
    /// @dev Output metadata does not match the output buffer.
    error IncompleteExecution();

    function outputMeta(uint descriptor, uint batches) private pure returns (uint meta) {
        uint spec = Descriptors.output(descriptor);
        uint count = Descriptors.outputs(descriptor, batches);
        if (count == 0) return 0;
        meta = Buffers.init(count * (Sizes.Header + Specs.hint(spec)), Specs.growable(spec));
    }

    function stateCursor(
        bytes calldata source,
        uint descriptor,
        uint expected
    ) private pure returns (uint state, uint groups) {
        (, uint group) = Descriptors.state(descriptor);
        (state, groups) = Cursors.initMeta(source, group, expected, Lanes.State);
    }

    function inputCursor(
        bytes calldata source,
        uint descriptor,
        uint expected
    ) private pure returns (uint input, uint groups) {
        (, , uint group) = Descriptors.input(descriptor);
        (input, groups) = Cursors.initMeta(source, group, expected, Lanes.Input);
    }

    function select(Execution memory exec, uint8 tag) private pure returns (uint cursors) {
        cursors = Spans.select(exec.cursors, tag);
        exec.cursors = cursors;
    }

    function position(Execution memory exec, uint8 tag) private pure returns (uint) {
        return Spans.abs(select(exec, tag));
    }

    function advance(Execution memory exec, uint size) private pure {
        exec.cursors = Spans.advance(exec.cursors, size);
    }

    function openState(
        bytes calldata source,
        uint descriptor,
        uint batches
    ) internal view returns (Execution memory exec) {
        uint state;
        (state, batches) = stateCursor(source, descriptor, batches);
        exec.budget = msg.value;
        exec.cursors = state;
        exec.writers = outputMeta(descriptor, batches);
    }

    function openInput(
        bytes calldata source,
        uint descriptor,
        uint batches
    ) internal view returns (Execution memory exec) {
        uint input;
        (input, batches) = inputCursor(source, descriptor, batches);
        exec.budget = msg.value;
        exec.cursors = input;
        exec.writers = outputMeta(descriptor, batches);
    }

    function open(
        bytes calldata stateSource,
        bytes calldata inputSource,
        uint descriptor,
        uint batches
    ) internal view returns (Execution memory exec) {
        uint input;
        uint state;
        (input, batches) = inputCursor(inputSource, descriptor, batches);
        (state, batches) = stateCursor(stateSource, descriptor, batches);
        exec.budget = msg.value;
        exec.cursors = Spans.pair(input, state);
        exec.writers = outputMeta(descriptor, batches);
    }

    /// @notice Return whether either execution cursor lane has blocks remaining.
    function more(Execution memory exec) internal pure returns (bool) {
        return Spans.any(exec.cursors);
    }

    function complete(Execution memory exec, uint8 tag) internal pure {
        Cursors.complete(Spans.select(exec.cursors, tag));
    }

    function unpack32(Execution memory exec, uint8 tag, uint spec) internal pure returns (bytes32 value) {
        uint abs = position(exec, tag);
        if (Blocks.header(abs, Specs.key(spec)) != 32) revert Blocks.InvalidBlock();
        assembly ("memory-safe") {
            value := calldataload(add(abs, 0x08))
        }
        advance(exec, Sizes.B32);
    }

    // Fixed-width block decoders

    function unpackAccount(Execution memory exec, uint8 tag) internal pure returns (bytes32 account) {
        uint abs = position(exec, tag);
        account = Blocks.unpackAccount(abs);
        advance(exec, Sizes.B32);
    }

    function unpackNode(Execution memory exec, uint8 tag) internal pure returns (uint node) {
        uint abs = position(exec, tag);
        node = Blocks.unpackNode(abs);
        advance(exec, Sizes.B32);
    }

    function unpackAsset(Execution memory exec, uint8 tag) internal pure returns (bytes32 asset) {
        uint abs = position(exec, tag);
        asset = Blocks.unpackAsset(abs);
        advance(exec, Sizes.B32);
    }

    function unpackAccountAsset(
        Execution memory exec,
        uint8 tag
    ) internal pure returns (bytes32 account, bytes32 asset) {
        uint abs = position(exec, tag);
        (account, asset) = Blocks.unpackAccountAsset(abs);
        advance(exec, Sizes.B64);
    }

    function unpackAccountAmount(
        Execution memory exec,
        uint8 tag
    ) internal pure returns (bytes32 account, bytes32 asset, uint amount) {
        uint abs = position(exec, tag);
        (account, asset, amount) = Blocks.unpackAccountAmount(abs);
        advance(exec, Sizes.B96);
    }

    function unpackAmount(Execution memory exec, uint8 tag) internal pure returns (bytes32 asset, uint amount) {
        uint abs = position(exec, tag);
        (asset, amount) = Blocks.unpackAmount(abs);
        advance(exec, Sizes.Amount);
    }

    function unpackBalance(Execution memory exec, uint8 tag) internal pure returns (bytes32 asset, uint amount) {
        uint abs = position(exec, tag);
        (asset, amount) = Blocks.unpackBalance(abs);
        advance(exec, Sizes.Balance);
    }

    function unpackBalanceForHost(
        Execution memory exec,
        uint8 tag,
        uint host
    ) internal pure returns (HostAmount memory value) {
        uint abs = position(exec, tag);
        value.host = host;
        (value.asset, value.amount) = Blocks.unpackBalance(abs);
        advance(exec, Sizes.Balance);
    }

    function unpackAllocationValue(Execution memory exec, uint8 tag) internal pure returns (HostAmount memory value) {
        uint abs = position(exec, tag);
        (value.host, value.asset, value.amount) = Blocks.unpackAllocation(abs);
        advance(exec, Sizes.B96);
    }

    function unpackAllowance(
        Execution memory exec,
        uint8 tag
    ) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint abs = position(exec, tag);
        (host, asset, amount) = Blocks.unpackAllowance(abs);
        advance(exec, Sizes.B96);
    }

    function unpackTransaction(
        Execution memory exec,
        uint8 tag
    ) internal pure returns (bytes32 from, bytes32 to, bytes32 asset, uint amount) {
        uint abs = position(exec, tag);
        (from, to, asset, amount) = Blocks.unpackTransaction(abs);
        advance(exec, Sizes.Transaction);
    }

    // Dynamic block decoders

    function unpackCall(
        Execution memory exec,
        uint8 tag
    ) internal pure returns (uint target, uint resources, bytes calldata data) {
        uint next;
        (target, resources, data, next) = Blocks.unpackCall(position(exec, tag));
        exec.cursors = Spans.seekAbs(exec.cursors, next);
    }

    function unpackContext(
        Execution memory exec,
        uint8 tag
    ) internal pure returns (bytes32 account, bytes calldata state, bytes calldata request) {
        uint next;
        (account, state, request, next) = Blocks.unpackContext(position(exec, tag));
        exec.cursors = Spans.seekAbs(exec.cursors, next);
    }

    function unpackDispatch(
        Execution memory exec,
        uint8 tag
    ) internal pure returns (uint portal, uint resources, bytes calldata payload) {
        uint next;
        (portal, resources, payload, next) = Blocks.unpackDispatch(position(exec, tag));
        exec.cursors = Spans.seekAbs(exec.cursors, next);
    }

    function unpackLabel(
        Execution memory exec,
        uint8 tag
    ) internal pure returns (uint id, bytes32 namespace, string memory name) {
        uint next;
        (id, namespace, name, next) = Blocks.unpackLabel(position(exec, tag));
        exec.cursors = Spans.seekAbs(exec.cursors, next);
    }

    function unpackSchema(
        Execution memory exec,
        uint8 tag
    ) internal pure returns (uint spec, string memory body, bytes32 name) {
        uint next;
        (spec, body, name, next) = Blocks.unpackSchema(position(exec, tag));
        exec.cursors = Spans.seekAbs(exec.cursors, next);
    }

    function unpackRecover(
        Execution memory exec,
        uint8 tag
    ) internal pure returns (uint handler, uint resources, bytes32 key, bytes calldata witness) {
        uint next;
        (handler, resources, key, witness, next) = Blocks.unpackRecover(position(exec, tag));
        exec.cursors = Spans.seekAbs(exec.cursors, next);
    }

    function relayToContext(
        Execution memory exec,
        uint8 tag,
        bytes32 account,
        bytes calldata state
    ) internal pure returns (uint portal, uint resources, bytes memory context) {
        bytes calldata request;
        uint next;
        (portal, resources, request, next) = Blocks.unpackRelay(position(exec, tag));
        exec.cursors = Spans.seekAbs(exec.cursors, next);
        context = Blocks.context(account, bytes(state), bytes(request));
    }

    function reserve(Execution memory exec, uint size) private pure returns (uint i) {
        (exec.writers, exec.output, i) = Buffers.reserve(exec.writers, exec.output, size, size);
    }

    function outputStatus(Execution memory exec, uint code) internal pure {
        uint i = reserve(exec, Sizes.Status);
        Blocks.writeStatus(exec.output, i, code);
    }

    function outputBalance(Execution memory exec, bytes32 asset, uint amount) internal pure {
        uint i = reserve(exec, Sizes.Balance);
        Blocks.writeBalance(exec.output, i, asset, amount);
    }

    function outputAccountAmount(Execution memory exec, bytes32 account, bytes32 asset, uint amount) internal pure {
        uint i = reserve(exec, Sizes.B96);
        Blocks.writeAccountAmount(exec.output, i, account, asset, amount);
    }

    function outputCustody(Execution memory exec, HostAmount memory value) internal pure {
        uint i = reserve(exec, Sizes.B96);
        Blocks.writeCustody(exec.output, i, value.host, value.asset, value.amount);
    }

    function finish(Execution memory exec) internal pure returns (bytes memory out) {
        (uint i, uint end, ) = Buffers.decode(exec.writers);
        if (i == 0) return new bytes(0);
        if (i > end || i > exec.output.length) revert IncompleteExecution();
        out = Buffers.trim(exec.output, i);
    }

    /// @notice Deduct the EVM value lane of `resources` from the execution budget.
    /// @dev EVM resources use the low 128 bits as native value/endowment.
    /// @param exec Mutable execution whose budget is charged.
    /// @param resources Packed resources whose value lane should be spent.
    /// @return value Native value to forward in wei.
    function useValue(Execution memory exec, uint resources) internal pure returns (uint128 value) {
        value = uint128(resources);
        if (value > exec.budget) revert InsufficientValue();
        exec.budget -= value;
    }

    function queueTransaction(
        Execution memory exec,
        bytes32 from,
        bytes32 to,
        bytes32 asset,
        uint amount
    ) internal pure {
        // INCOMPLETE: this currently allocates space for one transaction and
        // overwrites the queue from position zero on every call.
        exec.transactions = new bytes(Sizes.Transaction);
        Blocks.writeTransaction(exec.transactions, 0, from, to, asset, amount);
    }

    function queueDebit(Execution memory exec, bytes32 account, bytes32 asset, uint amount) internal pure {
        queueTransaction(exec, account, bytes32(0), asset, amount);
    }

    function queueCredit(Execution memory exec, bytes32 account, bytes32 asset, uint amount) internal pure {
        queueTransaction(exec, bytes32(0), account, asset, amount);
    }
}

/* 

Execution memory exec = openCommand(state, input, descriptor, 0);

while(exec.more()) {
    (bytes32 asset, uint amount) = exec.unpackBalance(Lanes.State);
}

return closeCommand(exec, account);

*/
