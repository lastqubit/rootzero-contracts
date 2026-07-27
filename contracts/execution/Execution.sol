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

    function select(Execution memory exec, uint8 tag_) private pure {
        exec.cursors = Spans.select(exec.cursors, tag_);
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

    function complete(Execution memory exec, uint8 tag_) internal pure {
        Cursors.complete(Spans.select(exec.cursors, tag_));
    }

    function unpack32(Execution memory exec, uint8 tag_, uint spec) internal pure returns (bytes32 value) {
        select(exec, tag_);
        (exec.cursors, value) = Cursors.unpack32(exec.cursors, spec);
    }

    function unpackAccount(Execution memory exec, uint8 tag_) internal pure returns (bytes32 account) {
        select(exec, tag_);
        (exec.cursors, account) = Cursors.unpackAccount(exec.cursors);
    }

    function unpackNode(Execution memory exec, uint8 tag_) internal pure returns (uint node) {
        select(exec, tag_);
        (exec.cursors, node) = Cursors.unpackNode(exec.cursors);
    }

    function unpackAsset(Execution memory exec, uint8 tag_) internal pure returns (bytes32 asset) {
        select(exec, tag_);
        (exec.cursors, asset) = Cursors.unpackAsset(exec.cursors);
    }

    function unpackAccountAsset(
        Execution memory exec,
        uint8 tag_
    ) internal pure returns (bytes32 account, bytes32 asset) {
        select(exec, tag_);
        (exec.cursors, account, asset) = Cursors.unpackAccountAsset(exec.cursors);
    }

    function unpackAccountAmount(
        Execution memory exec,
        uint8 tag_
    ) internal pure returns (bytes32 account, bytes32 asset, uint amount) {
        select(exec, tag_);
        (exec.cursors, account, asset, amount) = Cursors.unpackAccountAmount(exec.cursors);
    }

    function unpackAmount(Execution memory exec, uint8 tag_) internal pure returns (bytes32 asset, uint amount) {
        select(exec, tag_);
        (exec.cursors, asset, amount) = Cursors.unpackAmount(exec.cursors);
    }

    function unpackBalance(Execution memory exec, uint8 tag_) internal pure returns (bytes32 asset, uint amount) {
        select(exec, tag_);
        (exec.cursors, asset, amount) = Cursors.unpackBalance(exec.cursors);
    }

    function unpackBalanceForHost(
        Execution memory exec,
        uint8 tag_,
        uint host
    ) internal pure returns (HostAmount memory value) {
        select(exec, tag_);
        (exec.cursors, value) = Cursors.unpackBalanceForHost(exec.cursors, host);
    }

    function unpackAllocationValue(Execution memory exec, uint8 tag_) internal pure returns (HostAmount memory value) {
        select(exec, tag_);
        (exec.cursors, value) = Cursors.unpackAllocationValue(exec.cursors);
    }

    function unpackAllowance(
        Execution memory exec,
        uint8 tag_
    ) internal pure returns (uint host, bytes32 asset, uint amount) {
        select(exec, tag_);
        (exec.cursors, host, asset, amount) = Cursors.unpackAllowance(exec.cursors);
    }

    function unpackCall(
        Execution memory exec,
        uint8 tag_
    ) internal pure returns (uint target, uint resources, bytes calldata data) {
        select(exec, tag_);
        (exec.cursors, target, resources, data) = Cursors.unpackCall(exec.cursors);
    }

    function unpackContext(
        Execution memory exec,
        uint8 tag_
    ) internal pure returns (bytes32 account, bytes calldata state, bytes calldata request) {
        select(exec, tag_);
        (exec.cursors, account, state, request) = Cursors.unpackContext(exec.cursors);
    }

    function unpackDispatch(
        Execution memory exec,
        uint8 tag_
    ) internal pure returns (uint portal, uint resources, bytes calldata payload) {
        select(exec, tag_);
        (exec.cursors, portal, resources, payload) = Cursors.unpackDispatch(exec.cursors);
    }

    function unpackLabel(
        Execution memory exec,
        uint8 tag_
    ) internal pure returns (uint id, bytes32 namespace, string memory name) {
        select(exec, tag_);
        (exec.cursors, id, namespace, name) = Cursors.unpackLabel(exec.cursors);
    }

    function unpackSchema(
        Execution memory exec,
        uint8 tag_
    ) internal pure returns (uint spec, string memory body, bytes32 name) {
        select(exec, tag_);
        (exec.cursors, spec, body, name) = Cursors.unpackSchema(exec.cursors);
    }

    function unpackRecover(
        Execution memory exec,
        uint8 tag_
    ) internal pure returns (uint handler, uint resources, bytes32 key, bytes calldata witness) {
        select(exec, tag_);
        (exec.cursors, handler, resources, key, witness) = Cursors.unpackRecover(exec.cursors);
    }

    function unpackTransaction(
        Execution memory exec,
        uint8 tag_
    ) internal pure returns (bytes32 from, bytes32 to, bytes32 asset, uint amount) {
        select(exec, tag_);
        (exec.cursors, from, to, asset, amount) = Cursors.unpackTransaction(exec.cursors);
    }

    function relayToContext(
        Execution memory exec,
        uint8 tag_,
        bytes32 account,
        bytes calldata state
    ) internal pure returns (uint portal, uint resources, bytes memory context) {
        select(exec, tag_);
        (exec.cursors, portal, resources, context) = Cursors.relayToContext(exec.cursors, account, state);
    }

    function outputBlock32(Execution memory exec, uint spec, bytes32 value) internal pure {
        (exec.writers, exec.output) = Blocks.append32(exec.writers, exec.output, spec, value);
    }

    function outputStatus(Execution memory exec, uint code) internal pure {
        (exec.writers, exec.output) = Blocks.appendStatus(exec.writers, exec.output, code);
    }

    function outputBalance(Execution memory exec, bytes32 asset, uint amount) internal pure {
        (exec.writers, exec.output) = Blocks.appendBalance(exec.writers, exec.output, asset, amount);
    }

    function outputAccountAmount(Execution memory exec, bytes32 account, bytes32 asset, uint amount) internal pure {
        (exec.writers, exec.output) = Blocks.appendAccountAmount(exec.writers, exec.output, account, asset, amount);
    }

    function outputCustody(Execution memory exec, HostAmount memory value) internal pure {
        (exec.writers, exec.output) = Blocks.appendCustody(
            exec.writers,
            exec.output,
            value.host,
            value.asset,
            value.amount
        );
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
