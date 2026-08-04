// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AssetAmount, AccountAsset, AccountAmount, HostAmount, HostAccountAsset, Tx} from "../core/Types.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Buffers} from "../codec/Buffers.sol";
import {Sizes, Specs} from "../codec/Specs.sol";
import {Descriptors} from "../codec/Descriptors.sol";
import {Cursors, Cur} from "../utils/Cursors.sol";
import {Lanes} from "../utils/Lanes.sol";
import {Budget} from "./Budget.sol";

/// @notice Mutable state shared across one endpoint execution.
/// @dev `decoders` contains tagged input and state cursor lanes. Cursor operations
/// select one logical lane by swapping it into the lower 128 bits.
struct Execution {
    uint budget;
    uint decoders;
    uint writers;
    bytes transactions;
    bytes output;
}

/// @title Executions
/// @notice Opening, decoding, output, transaction, and value helpers for executions.
library Executions {
    using Cursors for uint;

    /// @dev Thrown when an execution attempts to spend more value than remains in its budget.
    error InsufficientValue();

    // -------------------------------------------------------------------------
    // Opening
    // -------------------------------------------------------------------------

    /// @dev A lane with stride zero accepts only an empty source and returns the zero cursor.
    /// @param source Calldata source for the decoder lane.
    /// @param descriptor Packed endpoint descriptor.
    /// @param lane Input or state lane identifier.
    /// @return cur Tagged packed decoder cursor, or zero for an absent lane.
    function openDecoder(bytes calldata source, uint descriptor, uint8 lane) private pure returns (uint cur) {
        uint stride = Descriptors.stride(descriptor, lane);
        (uint abs, uint limit) = Cursors.bounds(source);
        if (stride == 0 && abs == limit) return 0;

        bytes4 key = bytes4(source);
        (uint groups, uint end) = Blocks.scope(abs, limit, key, stride);
        cur = Cursors.create(abs, end - abs, groups, 0, lane);
    }

    /// @dev Initialize one tagged writer cursor from a descriptor lane.
    /// @param descriptor Packed endpoint descriptor.
    /// @param batches Reconciled execution batch count.
    /// @param lane Output or transaction lane identifier.
    /// @param padding Additional logical capacity reserved for the lane.
    /// @return cur Tagged packed writer cursor, or zero for an absent lane.
    function initWriter(uint descriptor, uint batches, uint8 lane, uint padding) private pure returns (uint cur) {
        (uint capacity, bool growable) = Descriptors.allocation(descriptor, lane, batches);
        if (capacity == 0) return 0;

        cur = Buffers.cursor(capacity + padding, batches, growable, lane);
    }

    /// @dev Open and pair the input and state decoder cursors.
    /// @param state State calldata source.
    /// @param input Input calldata source.
    /// @param descriptor Packed endpoint descriptor.
    /// @return Paired decoder cursors.
    function decodeCursors(bytes calldata state, bytes calldata input, uint descriptor) private pure returns (uint) {
        return
            Cursors.pair(openDecoder(input, descriptor, Lanes.Input), openDecoder(state, descriptor, Lanes.State));
    }

    /// @dev Initialize and pair the output and transaction writer cursors.
    /// @param descriptor Packed endpoint descriptor.
    /// @param batches Reconciled execution batch count.
    /// @return Paired writer cursors.
    function writerCursors(uint descriptor, uint batches) private pure returns (uint) {
        return
            Cursors.pair(
                initWriter(descriptor, batches, Lanes.Output, 0),
                initWriter(descriptor, batches, Lanes.Transactions, Sizes.Transaction)
            );
    }

    /// @dev Complete execution initialization from pre-opened decoder cursors.
    /// @param decoders Packed decoder cursor or pair.
    /// @param descriptor Packed endpoint descriptor.
    /// @param batches Expected batch count; zero derives it from the decoders.
    /// @return exec Initialized execution.
    function open(uint decoders, uint descriptor, uint batches) private view returns (Execution memory exec) {
        exec.budget = msg.value;
        exec.decoders = decoders;
        batches = Cursors.reconcile(decoders, batches);
        exec.writers = writerCursors(descriptor, batches);
    }

    /// @notice Open an execution containing only the current call-value budget.
    /// @dev Decoders, writers, output, and transactions remain empty.
    /// @return exec Budget-only execution initialized with `msg.value`.
    function open() internal view returns (Execution memory exec) {
        exec.budget = msg.value;
    }

    /// @notice Open an execution with an input decoder and descriptor writers.
    /// @param input Input block stream.
    /// @param descriptor Packed endpoint descriptor.
    /// @param batches Expected batch count; zero derives it from the input run.
    /// @return exec Initialized execution.
    function openInput(
        bytes calldata input,
        uint descriptor,
        uint batches
    ) internal view returns (Execution memory exec) {
        return open(openDecoder(input, descriptor, Lanes.Input), descriptor, batches);
    }

    /// @notice Open an execution with a state decoder and descriptor writers.
    /// @param state State block stream.
    /// @param descriptor Packed endpoint descriptor.
    /// @param batches Expected batch count; zero derives it from the state run.
    /// @return exec Initialized execution.
    function openState(
        bytes calldata state,
        uint descriptor,
        uint batches
    ) internal view returns (Execution memory exec) {
        return open(openDecoder(state, descriptor, Lanes.State), descriptor, batches);
    }

    /// @notice Open an execution with paired state and input decoders.
    /// @param state State block stream.
    /// @param input Input block stream.
    /// @param descriptor Packed endpoint descriptor.
    /// @param batches Expected batch count; zero derives it from the decoder runs.
    /// @return exec Initialized execution.
    function open(
        bytes calldata state,
        bytes calldata input,
        uint descriptor,
        uint batches
    ) internal view returns (Execution memory exec) {
        return open(decodeCursors(state, input, descriptor), descriptor, batches);
    }

    // -------------------------------------------------------------------------
    // Traversal
    // -------------------------------------------------------------------------

    /// @notice Return whether either execution decoder lane has blocks remaining.
    /// @param exec Execution to inspect.
    /// @return Whether either decoder lane has unread bytes.
    function more(Execution memory exec) internal pure returns (bool) {
        return exec.decoders.any();
    }

    /// @notice Validate and consume the next block from an execution decoder lane.
    /// @param exec Execution whose selected decoder cursor is advanced over the complete block.
    /// @param lane Execution decoder lane to select.
    /// @param spec Expected block specification.
    /// @return abs Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function consume(Execution memory exec, uint8 lane, uint spec) internal pure returns (uint abs, uint end) {
        uint cur = exec.decoders.select(lane);
        (abs, end) = Blocks.expect(cur.absolute(), spec);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Consume a LIST block and return a cursor scoped to its payload.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane containing the LIST block.
    /// @return items Cursor over the nested list items.
    function list(Execution memory exec, uint8 lane) internal pure returns (Cur memory items) {
        (uint abs, uint end) = consume(exec, lane, Specs.List);
        items.state = Cursors.create(abs, end - abs, 0, 0, 0);
    }

    // -------------------------------------------------------------------------
    // Fixed-width block decoding
    // -------------------------------------------------------------------------

    /// @notice Decode one fixed 32-byte payload from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @param spec Expected fixed block specification.
    /// @return value Decoded payload word.
    function unpack32(Execution memory exec, uint8 lane, uint spec) internal pure returns (bytes32 value) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.B32);
        if (Blocks.header(abs, Specs.key(spec)) != 32) revert Blocks.InvalidBlock();
        assembly ("memory-safe") {
            value := calldataload(add(abs, 0x08))
        }
    }

    /// @notice Decode and consume one ACCOUNT block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return account Decoded account identifier.
    function unpackAccount(Execution memory exec, uint8 lane) internal pure returns (bytes32 account) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.B32);
        account = Blocks.unpackAccount(abs);
    }

    /// @notice Decode and consume one NODE block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return node Decoded node identifier.
    function unpackNode(Execution memory exec, uint8 lane) internal pure returns (uint node) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.B32);
        node = Blocks.unpackNode(abs);
    }

    /// @notice Decode and consume one ASSET block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return asset Decoded asset identifier.
    function unpackAsset(Execution memory exec, uint8 lane) internal pure returns (bytes32 asset) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.B32);
        asset = Blocks.unpackAsset(abs);
    }

    /// @notice Decode and consume one ACCOUNT_ASSET block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    function unpackAccountAsset(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (bytes32 account, bytes32 asset) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.B64);
        (account, asset) = Blocks.unpackAccountAsset(abs);
    }

    /// @notice Decode one ACCOUNT_ASSET block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return value Decoded account and asset.
    function unpackAccountAssetValue(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (AccountAsset memory value) {
        (value.account, value.asset) = unpackAccountAsset(exec, lane);
    }

    /// @notice Decode and consume one AMOUNT block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
    function unpackAmount(Execution memory exec, uint8 lane) internal pure returns (bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.Amount);
        (asset, amount) = Blocks.unpackAmount(abs);
    }

    /// @notice Decode one AMOUNT block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return value Decoded asset and amount.
    function unpackAmountValue(Execution memory exec, uint8 lane) internal pure returns (AssetAmount memory value) {
        (value.asset, value.amount) = unpackAmount(exec, lane);
    }

    /// @notice Decode and consume one BALANCE block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded balance amount.
    function unpackBalance(Execution memory exec, uint8 lane) internal pure returns (bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.Balance);
        (asset, amount) = Blocks.unpackBalance(abs);
    }

    /// @notice Decode one BALANCE block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return value Decoded asset and balance amount.
    function unpackBalanceValue(Execution memory exec, uint8 lane) internal pure returns (AssetAmount memory value) {
        (value.asset, value.amount) = unpackBalance(exec, lane);
    }

    /// @notice Decode one BALANCE block and associate it with `host`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @param host Host associated with the decoded balance.
    /// @return value Host-scoped asset amount.
    function unpackBalanceForHost(
        Execution memory exec,
        uint8 lane,
        uint host
    ) internal pure returns (HostAmount memory value) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.Balance);
        value.host = host;
        (value.asset, value.amount) = Blocks.unpackBalance(abs);
    }

    /// @notice Decode and consume one ACCOUNT_AMOUNT block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
    function unpackAccountAmount(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (bytes32 account, bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.B96);
        (account, asset, amount) = Blocks.unpackAccountAmount(abs);
    }

    /// @notice Decode one ACCOUNT_AMOUNT block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return value Decoded account, asset, and amount.
    function unpackAccountAmountValue(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (AccountAmount memory value) {
        (value.account, value.asset, value.amount) = unpackAccountAmount(exec, lane);
    }

    /// @notice Decode and consume one ALLOCATION block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
    function unpackAllocation(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.B96);
        (host, asset, amount) = Blocks.unpackAllocation(abs);
    }

    /// @notice Decode one ALLOCATION block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return value Decoded host, asset, and amount.
    function unpackAllocationValue(Execution memory exec, uint8 lane) internal pure returns (HostAmount memory value) {
        (value.host, value.asset, value.amount) = unpackAllocation(exec, lane);
    }

    /// @notice Decode and consume one ALLOWANCE block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded allowance amount.
    function unpackAllowance(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.B96);
        (host, asset, amount) = Blocks.unpackAllowance(abs);
    }

    /// @notice Decode one ALLOWANCE block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return value Decoded host, asset, and allowance amount.
    function unpackAllowanceValue(Execution memory exec, uint8 lane) internal pure returns (HostAmount memory value) {
        (value.host, value.asset, value.amount) = unpackAllowance(exec, lane);
    }

    /// @notice Decode and consume one CUSTODY block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded custody amount.
    function unpackCustody(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.B96);
        (host, asset, amount) = Blocks.unpackCustody(abs);
    }

    /// @notice Decode one CUSTODY block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return value Decoded host, asset, and custody amount.
    function unpackCustodyValue(Execution memory exec, uint8 lane) internal pure returns (HostAmount memory value) {
        (value.host, value.asset, value.amount) = unpackCustody(exec, lane);
    }

    /// @notice Decode and consume one HOST_ACCOUNT_ASSET block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return host Decoded host identifier.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    function unpackHostAccountAsset(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (uint host, bytes32 account, bytes32 asset) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.B96);
        (host, account, asset) = Blocks.unpackHostAccountAsset(abs);
    }

    /// @notice Decode one HOST_ACCOUNT_ASSET block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return value Decoded host, account, and asset.
    function unpackHostAccountAssetValue(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (HostAccountAsset memory value) {
        (value.host, value.account, value.asset) = unpackHostAccountAsset(exec, lane);
    }

    /// @notice Decode and consume one TRANSACTION block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return from Decoded debit account.
    /// @return to Decoded credit account.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded transaction amount.
    function unpackTransaction(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (bytes32 from, bytes32 to, bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(lane, Sizes.Transaction);
        (from, to, asset, amount) = Blocks.unpackTransaction(abs);
    }

    /// @notice Decode one TRANSACTION block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return value Decoded transaction.
    function unpackTransactionValue(Execution memory exec, uint8 lane) internal pure returns (Tx memory value) {
        (value.from, value.to, value.asset, value.amount) = unpackTransaction(exec, lane);
    }

    // -------------------------------------------------------------------------
    // Dynamic block decoding
    // -------------------------------------------------------------------------

    /// @notice Decode and consume a block described by `spec` from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @param spec Expected block specification.
    /// @return data Calldata view of the decoded payload.
    function unpackRaw(Execution memory exec, uint8 lane, uint spec) internal pure returns (bytes calldata data) {
        uint cur = exec.decoders.select(lane);
        uint end;
        (data, end) = Blocks.unpackRaw(cur.absolute(), spec);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one BYTES block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return data Decoded byte payload.
    function unpackBytes(Execution memory exec, uint8 lane) internal pure returns (bytes calldata data) {
        uint cur = exec.decoders.select(lane);
        uint end;
        (data, end) = Blocks.unpackBytes(cur.absolute());
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one STRING block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return data Decoded string payload.
    function unpackString(Execution memory exec, uint8 lane) internal pure returns (string memory data) {
        uint cur = exec.decoders.select(lane);
        bytes calldata value;
        uint end;
        (value, end) = Blocks.unpackString(cur.absolute());
        exec.decoders = cur.seekAbs(end);
        data = string(value);
    }

    /// @notice Decode and consume one STEP block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return cmd Decoded command identifier.
    /// @return resources Decoded packed resources.
    /// @return input Decoded nested input.
    function unpackStep(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (uint cmd, uint resources, bytes calldata input) {
        uint cur = exec.decoders.select(lane);
        uint end;
        (cmd, resources, input, end) = Blocks.unpackStep(cur.absolute());
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one CALL block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return target Decoded call target.
    /// @return resources Decoded packed resources.
    /// @return data Decoded call payload.
    function unpackCall(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (uint target, uint resources, bytes calldata data) {
        uint cur = exec.decoders.select(lane);
        uint abs = cur.absolute();
        uint end;
        (target, resources, data, end) = Blocks.unpackCall(abs);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one CONTEXT block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return account Decoded account identifier.
    /// @return state Decoded nested state.
    /// @return input Decoded nested input.
    function unpackContext(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (bytes32 account, bytes calldata state, bytes calldata input) {
        uint cur = exec.decoders.select(lane);
        uint abs = cur.absolute();
        uint end;
        (account, state, input, end) = Blocks.unpackContext(abs);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one RELAY block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return portal Decoded destination portal.
    /// @return resources Decoded packed resources.
    /// @return input Decoded nested input.
    function unpackRelay(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (uint portal, uint resources, bytes calldata input) {
        uint cur = exec.decoders.select(lane);
        uint end;
        (portal, resources, input, end) = Blocks.unpackRelay(cur.absolute());
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one DISPATCH block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return portal Decoded destination portal.
    /// @return resources Decoded packed resources.
    /// @return payload Decoded dispatch payload.
    function unpackDispatch(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (uint portal, uint resources, bytes calldata payload) {
        uint cur = exec.decoders.select(lane);
        uint abs = cur.absolute();
        uint end;
        (portal, resources, payload, end) = Blocks.unpackDispatch(abs);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one LABEL block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return id Decoded node identifier.
    /// @return namespace Decoded label namespace.
    /// @return name Decoded label text.
    function unpackLabel(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (uint id, bytes32 namespace, string memory name) {
        uint cur = exec.decoders.select(lane);
        uint abs = cur.absolute();
        uint end;
        (id, namespace, name, end) = Blocks.unpackLabel(abs);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one SCHEMA block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return spec Decoded block specification.
    /// @return body Decoded schema body.
    /// @return name Decoded schema name.
    function unpackSchema(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (uint spec, string memory body, bytes32 name) {
        uint cur = exec.decoders.select(lane);
        uint abs = cur.absolute();
        uint end;
        (spec, body, name, end) = Blocks.unpackSchema(abs);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one RECOVER block from `lane`.
    /// @param exec Execution whose decoder is advanced.
    /// @param lane Decoder lane to consume.
    /// @return handler Decoded recovery handler.
    /// @return resources Decoded packed resources.
    /// @return key Decoded recovery key.
    /// @return witness Decoded recovery witness.
    function unpackRecover(
        Execution memory exec,
        uint8 lane
    ) internal pure returns (uint handler, uint resources, bytes32 key, bytes calldata witness) {
        uint cur = exec.decoders.select(lane);
        uint abs = cur.absolute();
        uint end;
        (handler, resources, key, witness, end) = Blocks.unpackRecover(abs);
        exec.decoders = cur.seekAbs(end);
    }

    // -------------------------------------------------------------------------
    // Output writing
    // -------------------------------------------------------------------------

    /// @dev Reserve output capacity and advance its writer cursor.
    /// @param exec Execution whose output writer is advanced.
    /// @param amount Logical number of bytes written.
    /// @param touch Number of bytes that must be addressable by the write.
    /// @return i Relative output offset reserved for the write.
    function reserve(Execution memory exec, uint amount, uint touch) internal pure returns (uint i) {
        uint writers = exec.writers.select(Lanes.Output);
        (exec.writers, exec.output, i) = Buffers.reserve(writers, exec.output, amount, touch);
    }

    /// @dev Reserve an exact number of output bytes.
    /// @param exec Execution whose output writer is advanced.
    /// @param size Number of bytes to reserve and touch.
    /// @return i Relative output offset reserved for the write.
    function reserve(Execution memory exec, uint size) private pure returns (uint i) {
        return reserve(exec, size, size);
    }

    /// @notice Append an ACCOUNT block to execution output.
    /// @param exec Execution receiving the block.
    /// @param account Account identifier to encode.
    function outputAccount(Execution memory exec, bytes32 account) internal pure {
        uint i = reserve(exec, Sizes.B32);
        Blocks.writeAccount(exec.output, i, account);
    }

    /// @notice Append an ASSET block to execution output.
    /// @param exec Execution receiving the block.
    /// @param asset Asset identifier to encode.
    function outputAsset(Execution memory exec, bytes32 asset) internal pure {
        uint i = reserve(exec, Sizes.B32);
        Blocks.writeAsset(exec.output, i, asset);
    }

    /// @notice Append a NODE block to execution output.
    /// @param exec Execution receiving the block.
    /// @param node Node identifier to encode.
    function outputNode(Execution memory exec, uint node) internal pure {
        uint i = reserve(exec, Sizes.B32);
        Blocks.writeNode(exec.output, i, node);
    }

    /// @notice Append a STATUS block to execution output.
    /// @param exec Execution receiving the block.
    /// @param code Status code to encode.
    function outputStatus(Execution memory exec, uint code) internal pure {
        uint i = reserve(exec, Sizes.B32);
        Blocks.writeStatus(exec.output, i, code);
    }

    /// @notice Append an AMOUNT block to execution output.
    /// @param exec Execution receiving the block.
    /// @param asset Asset identifier to encode.
    /// @param amount Asset amount to encode.
    function outputAmount(Execution memory exec, bytes32 asset, uint amount) internal pure {
        uint i = reserve(exec, Sizes.B64);
        Blocks.writeAmount(exec.output, i, asset, amount);
    }

    /// @notice Append a structured AMOUNT value to execution output.
    /// @param exec Execution receiving the block.
    /// @param value Structured asset amount to encode.
    function outputAmount(Execution memory exec, AssetAmount memory value) internal pure {
        outputAmount(exec, value.asset, value.amount);
    }

    /// @notice Append a BALANCE block to execution output.
    /// @param exec Execution receiving the block.
    /// @param asset Asset identifier to encode.
    /// @param amount Balance amount to encode.
    function outputBalance(Execution memory exec, bytes32 asset, uint amount) internal pure {
        uint i = reserve(exec, Sizes.B64);
        Blocks.writeBalance(exec.output, i, asset, amount);
    }

    /// @notice Append a structured BALANCE value to execution output.
    /// @param exec Execution receiving the block.
    /// @param value Structured asset balance to encode.
    function outputBalance(Execution memory exec, AssetAmount memory value) internal pure {
        outputBalance(exec, value.asset, value.amount);
    }

    /// @notice Append an ACCOUNT_ASSET block to execution output.
    /// @param exec Execution receiving the block.
    /// @param account Account identifier to encode.
    /// @param asset Asset identifier to encode.
    function outputAccountAsset(Execution memory exec, bytes32 account, bytes32 asset) internal pure {
        uint i = reserve(exec, Sizes.B64);
        Blocks.writeAccountAsset(exec.output, i, account, asset);
    }

    /// @notice Append an ALLOCATION block to execution output.
    /// @param exec Execution receiving the block.
    /// @param host Host identifier to encode.
    /// @param asset Asset identifier to encode.
    /// @param amount Allocation amount to encode.
    function outputAllocation(Execution memory exec, uint host, bytes32 asset, uint amount) internal pure {
        uint i = reserve(exec, Sizes.B96);
        Blocks.writeAllocation(exec.output, i, host, asset, amount);
    }

    /// @notice Append an ALLOWANCE block to execution output.
    /// @param exec Execution receiving the block.
    /// @param host Host identifier to encode.
    /// @param asset Asset identifier to encode.
    /// @param amount Allowance amount to encode.
    function outputAllowance(Execution memory exec, uint host, bytes32 asset, uint amount) internal pure {
        uint i = reserve(exec, Sizes.B96);
        Blocks.writeAllowance(exec.output, i, host, asset, amount);
    }

    /// @notice Append a CUSTODY block to execution output.
    /// @param exec Execution receiving the block.
    /// @param host Host identifier to encode.
    /// @param asset Asset identifier to encode.
    /// @param amount Custody amount to encode.
    function outputCustody(Execution memory exec, uint host, bytes32 asset, uint amount) internal pure {
        uint i = reserve(exec, Sizes.B96);
        Blocks.writeCustody(exec.output, i, host, asset, amount);
    }

    /// @notice Append a CUSTODY block for `host` and a structured amount.
    /// @param exec Execution receiving the block.
    /// @param host Host identifier to encode.
    /// @param value Structured asset amount to encode.
    function outputCustody(Execution memory exec, uint host, AssetAmount memory value) internal pure {
        outputCustody(exec, host, value.asset, value.amount);
    }

    /// @notice Append a structured CUSTODY value to execution output.
    /// @param exec Execution receiving the block.
    /// @param value Structured host asset amount to encode.
    function outputCustody(Execution memory exec, HostAmount memory value) internal pure {
        outputCustody(exec, value.host, value.asset, value.amount);
    }

    /// @notice Append an ACCOUNT_AMOUNT block to execution output.
    /// @param exec Execution receiving the block.
    /// @param account Account identifier to encode.
    /// @param asset Asset identifier to encode.
    /// @param amount Account amount to encode.
    function outputAccountAmount(Execution memory exec, bytes32 account, bytes32 asset, uint amount) internal pure {
        uint i = reserve(exec, Sizes.B96);
        Blocks.writeAccountAmount(exec.output, i, account, asset, amount);
    }

    /// @notice Append a structured ACCOUNT_AMOUNT value to execution output.
    /// @param exec Execution receiving the block.
    /// @param value Structured account asset amount to encode.
    function outputAccountAmount(Execution memory exec, AccountAmount memory value) internal pure {
        outputAccountAmount(exec, value.account, value.asset, value.amount);
    }

    /// @notice Append a HOST_AMOUNT block to execution output.
    /// @param exec Execution receiving the block.
    /// @param host Host identifier to encode.
    /// @param asset Asset identifier to encode.
    /// @param amount Host amount to encode.
    function outputHostAmount(Execution memory exec, uint host, bytes32 asset, uint amount) internal pure {
        uint i = reserve(exec, Sizes.B96);
        Blocks.writeHostAmount(exec.output, i, host, asset, amount);
    }

    /// @notice Append a HOST_ACCOUNT_ASSET block to execution output.
    /// @param exec Execution receiving the block.
    /// @param host Host identifier to encode.
    /// @param account Account identifier to encode.
    /// @param asset Asset identifier to encode.
    function outputHostAccountAsset(Execution memory exec, uint host, bytes32 account, bytes32 asset) internal pure {
        uint i = reserve(exec, Sizes.B96);
        Blocks.writeHostAccountAsset(exec.output, i, host, account, asset);
    }

    /// @notice Append a TRANSACTION block to regular execution output.
    /// @param exec Execution receiving the block.
    /// @param from Debit account identifier.
    /// @param to Credit account identifier.
    /// @param asset Asset identifier to encode.
    /// @param amount Transaction amount to encode.
    function outputTransaction(
        Execution memory exec,
        bytes32 from,
        bytes32 to,
        bytes32 asset,
        uint amount
    ) internal pure {
        uint i = reserve(exec, Sizes.B128);
        Blocks.writeTransaction(exec.output, i, from, to, asset, amount);
    }

    /// @notice Append a structured TRANSACTION value to regular execution output.
    /// @param exec Execution receiving the block.
    /// @param value Structured transaction to encode.
    function outputTransaction(Execution memory exec, Tx memory value) internal pure {
        outputTransaction(exec, value.from, value.to, value.asset, value.amount);
    }

    /// @notice Append a HOST_ACCOUNT_AMOUNT block to execution output.
    /// @param exec Execution receiving the block.
    /// @param host Host identifier to encode.
    /// @param account Account identifier to encode.
    /// @param asset Asset identifier to encode.
    /// @param amount Host account amount to encode.
    function outputHostAccountAmount(
        Execution memory exec,
        uint host,
        bytes32 account,
        bytes32 asset,
        uint amount
    ) internal pure {
        uint i = reserve(exec, Sizes.B128);
        Blocks.writeHostAccountAmount(exec.output, i, host, account, asset, amount);
    }

    /// @notice Append a LIST block to execution output.
    /// @param exec Execution receiving the block.
    /// @param value Encoded list payload.
    function outputList(Execution memory exec, bytes memory value) internal pure {
        uint size = Sizes.Header + value.length;
        uint i = reserve(exec, size);
        Blocks.writeList(exec.output, i, value);
    }

    /// @notice Append an EVM block to execution output.
    /// @param exec Execution receiving the block.
    /// @param value EVM payload to encode.
    function outputEvm(Execution memory exec, bytes memory value) internal pure {
        uint size = Sizes.Header + value.length;
        uint i = reserve(exec, size);
        Blocks.writeEvm(exec.output, i, value);
    }

    /// @notice Append a BYTES block to execution output.
    /// @param exec Execution receiving the block.
    /// @param value Byte payload to encode.
    function outputBytes(Execution memory exec, bytes memory value) internal pure {
        uint size = Sizes.Header + value.length;
        uint i = reserve(exec, size);
        Blocks.writeBytes(exec.output, i, value);
    }

    /// @notice Append a STRING block to execution output.
    /// @param exec Execution receiving the block.
    /// @param value String payload to encode.
    function outputString(Execution memory exec, string memory value) internal pure {
        uint size = Sizes.Header + bytes(value).length;
        uint i = reserve(exec, size);
        Blocks.writeString(exec.output, i, value);
    }

    /// @notice Append a STEP block to execution output.
    /// @param exec Execution receiving the block.
    /// @param cmd Command identifier to encode.
    /// @param resources Packed resources to encode.
    /// @param input Command input to encode.
    function outputStep(Execution memory exec, uint cmd, uint resources, bytes memory input) internal pure {
        uint size = Sizes.B64 + Sizes.Header + input.length;
        uint i = reserve(exec, size);
        Blocks.writeStep(exec.output, i, cmd, resources, input);
    }

    /// @notice Append a CALL block to execution output.
    /// @param exec Execution receiving the block.
    /// @param target Call target to encode.
    /// @param resources Packed resources to encode.
    /// @param payload Call payload to encode.
    function outputCall(Execution memory exec, uint target, uint resources, bytes memory payload) internal pure {
        uint size = Sizes.B64 + Sizes.Header + payload.length;
        uint i = reserve(exec, size);
        Blocks.writeCall(exec.output, i, target, resources, payload);
    }

    /// @notice Append a RELAY block to execution output.
    /// @param exec Execution receiving the block.
    /// @param portal Destination portal to encode.
    /// @param resources Packed resources to encode.
    /// @param input Relay input to encode.
    function outputRelay(Execution memory exec, uint portal, uint resources, bytes memory input) internal pure {
        uint size = Sizes.B64 + Sizes.Header + input.length;
        uint i = reserve(exec, size);
        Blocks.writeRelay(exec.output, i, portal, resources, input);
    }

    /// @notice Append a DISPATCH block to execution output.
    /// @param exec Execution receiving the block.
    /// @param portal Destination portal to encode.
    /// @param resources Packed resources to encode.
    /// @param payload Dispatch payload to encode.
    function outputDispatch(Execution memory exec, uint portal, uint resources, bytes memory payload) internal pure {
        uint size = Sizes.B64 + Sizes.Header + payload.length;
        uint i = reserve(exec, size);
        Blocks.writeDispatch(exec.output, i, portal, resources, payload);
    }

    /// @notice Append a CONTEXT block to execution output.
    /// @param exec Execution receiving the block.
    /// @param account Account identifier to encode.
    /// @param state State payload to encode.
    /// @param input Input payload to encode.
    function outputContext(
        Execution memory exec,
        bytes32 account,
        bytes memory state,
        bytes memory input
    ) internal pure {
        uint size = Sizes.B32 + 2 * Sizes.Header + state.length + input.length;
        uint i = reserve(exec, size);
        Blocks.writeContext(exec.output, i, account, state, input);
    }

    /// @notice Append a RECOVER block to execution output.
    /// @param exec Execution receiving the block.
    /// @param handler Recovery handler to encode.
    /// @param resources Packed resources to encode.
    /// @param recoverykey Recovery key to encode.
    /// @param witness Recovery witness to encode.
    function outputRecover(
        Execution memory exec,
        uint handler,
        uint resources,
        bytes32 recoverykey,
        bytes memory witness
    ) internal pure {
        uint size = Sizes.B96 + Sizes.Header + witness.length;
        uint i = reserve(exec, size);
        Blocks.writeRecover(exec.output, i, handler, resources, recoverykey, witness);
    }

    /// @notice Append a LABEL block to execution output.
    /// @param exec Execution receiving the block.
    /// @param id Node identifier to encode.
    /// @param namespace Label namespace to encode.
    /// @param name Label text to encode.
    function outputLabel(Execution memory exec, uint id, bytes32 namespace, string memory name) internal pure {
        uint size = Sizes.B64 + Sizes.Header + bytes(name).length;
        uint i = reserve(exec, size);
        Blocks.writeLabel(exec.output, i, id, namespace, name);
    }

    /// @notice Append a SCHEMA block to execution output.
    /// @param exec Execution receiving the block.
    /// @param spec Block specification to encode.
    /// @param body Schema body to encode.
    /// @param name Schema name to encode.
    function outputSchema(Execution memory exec, uint spec, string memory body, bytes32 name) internal pure {
        uint size = Sizes.B64 + Sizes.Header + bytes(body).length;
        uint i = reserve(exec, size);
        Blocks.writeSchema(exec.output, i, spec, body, name);
    }

    // -------------------------------------------------------------------------
    // Value and transaction writing
    // -------------------------------------------------------------------------

    /// @notice Transfer the remaining value budget out of an execution.
    /// @dev Clears `exec.budget` so the returned budget becomes its sole owner.
    /// @param exec Execution whose budget is detached.
    /// @return budget Detached budget containing the remaining value.
    function takeBudget(Execution memory exec) internal pure returns (Budget memory budget) {
        budget.remaining = exec.budget;
        exec.budget = 0;
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

    /// @notice Append a deferred transaction to the transaction writer lane.
    /// @param exec Execution receiving the transaction.
    /// @param from Debit account identifier.
    /// @param to Credit account identifier.
    /// @param asset Asset identifier.
    /// @param amount Transaction amount.
    function queueTransaction(
        Execution memory exec,
        bytes32 from,
        bytes32 to,
        bytes32 asset,
        uint amount
    ) internal pure {
        uint i;
        uint size = Sizes.Transaction;
        uint writers = exec.writers.select(Lanes.Transactions);
        (exec.writers, exec.transactions, i) = Buffers.reserve(writers, exec.transactions, size, size);
        Blocks.writeTransaction(exec.transactions, i, from, to, asset, amount);
    }

    /// @notice Queue a transaction that debits `account`.
    /// @param exec Execution receiving the transaction.
    /// @param account Account to debit.
    /// @param asset Asset to debit.
    /// @param amount Amount to debit.
    function queueDebit(Execution memory exec, bytes32 account, bytes32 asset, uint amount) internal pure {
        queueTransaction(exec, account, bytes32(0), asset, amount);
    }

    /// @notice Queue a transaction that credits `account`.
    /// @param exec Execution receiving the transaction.
    /// @param account Account to credit.
    /// @param asset Asset to credit.
    /// @param amount Amount to credit.
    function queueCredit(Execution memory exec, bytes32 account, bytes32 asset, uint amount) internal pure {
        queueTransaction(exec, bytes32(0), account, asset, amount);
    }

    /// @notice Drain the remaining value budget and queue it as an account refund.
    /// @dev Creates a one-transaction writer lane when the descriptor declared none.
    /// @param exec Execution whose remaining budget is refunded.
    /// @param account Account receiving the refund.
    /// @param asset Asset identifier used for the refund transaction.
    /// @return amount Value removed from the execution budget and queued for refund.
    function refundValue(Execution memory exec, bytes32 account, bytes32 asset) internal pure returns (uint amount) {
        amount = exec.budget;
        if (amount == 0) return 0;

        exec.budget = 0;
        if (!exec.writers.contains(Lanes.Transactions)) {
            uint refunds = Buffers.cursor(Sizes.Transaction, 1, false, Lanes.Transactions);
            exec.writers = Cursors.pair(exec.writers, refunds);
        }

        queueCredit(exec, account, asset, amount);
    }

    // -------------------------------------------------------------------------
    // Finalization
    // -------------------------------------------------------------------------

    /// @notice Finalize and return regular execution output.
    /// @param exec Execution whose output is finalized.
    /// @return out Trimmed output bytes.
    function finish(Execution memory exec) internal pure returns (bytes memory out) {
        if (exec.output.length == 0) return new bytes(0);

        uint writers = exec.writers.select(Lanes.Output);
        out = Buffers.finish(writers, exec.output);
    }

    /// @notice Finalize and return queued execution transactions.
    /// @param exec Execution whose transactions are finalized.
    /// @return out Trimmed transaction bytes.
    function finishTransactions(Execution memory exec) internal pure returns (bytes memory out) {
        if (exec.transactions.length == 0) return new bytes(0);

        uint writers = exec.writers.select(Lanes.Transactions);
        out = Buffers.finish(writers, exec.transactions);
    }
}
