// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AssetAmount, AccountAsset, HostAsset, AccountAmount, HostAmount, HostAccountAsset, Debt, Position, Tx} from "../core/Types.sol";
import {Blocks} from "../codec/Blocks.sol";
import {Buffers} from "../codec/Buffers.sol";
import {Sizes, Specs} from "../codec/Specs.sol";
import {Cursors, Cur} from "../utils/Cursors.sol";
import {InsufficientValue, UnconsumedData} from "../utils/Errors.sol";
import {Lanes} from "../utils/Lanes.sol";
import {Budget} from "./Budget.sol";

/// @notice Mutable state shared across one endpoint execution.
/// @dev `decoders` contains tagged input and state cursor lanes. Cursor operations
/// select one logical lane by swapping it into the lower 128 bits.
struct Execution {
    bytes32 account;
    uint budget;
    uint decoders;
    uint writer;
    bytes output;
}

/// @title Executions
/// @notice Opening, decoding, output, and value helpers for executions.
/// @dev `output*` helpers consume memory inputs; `outputCopy*` helpers copy
/// calldata inputs directly to the output lane.
library Executions {
    using Cursors for uint;

    // -------------------------------------------------------------------------
    // Opening
    // -------------------------------------------------------------------------

    /// @notice Open an execution containing only the current call-value budget.
    /// @dev Decoders, writer, and output remain empty.
    /// @return exec Budget-only execution initialized with `msg.value`.
    function open() internal view returns (Execution memory exec) {
        exec.budget = msg.value;
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

    /// @notice Make the input decoder the active low lane.
    /// @return exec The same execution, allowing chained decoding.
    function oninput(Execution memory exec) internal pure returns (Execution memory) {
        exec.decoders = exec.decoders.select(Lanes.Input);
        return exec;
    }

    /// @notice Make the state decoder the active low lane.
    /// @return exec The same execution, allowing chained decoding.
    function onstate(Execution memory exec) internal pure returns (Execution memory) {
        exec.decoders = exec.decoders.select(Lanes.State);
        return exec;
    }

    /// @notice Return the active decoder's current absolute calldata position.
    /// @param exec Execution whose decoder is inspected.
    /// @return Current absolute calldata position of the active lane.
    function absolute(Execution memory exec) internal pure returns (uint) {
        return exec.decoders.absolute();
    }

    /// @dev Return the unread bounded calldata source for a decoder lane.
    /// A lane absent because its descriptor is EMPTY returns an empty calldata slice.
    /// @param exec Execution whose input or state source is requested.
    /// @return data Unread calldata region from the lane's current position.
    function raw(Execution memory exec, uint8 lane) private pure returns (bytes calldata data) {
        if (!exec.decoders.contains(lane)) return msg.data[0:0];

        uint cur = exec.decoders.select(lane);
        if (uint8(cur >> 96) == 0) return msg.data[0:0];
        (uint i, uint offset, uint len) = cur.decode();
        if (len > msg.data.length || offset > msg.data.length - len) {
            revert Blocks.MalformedBlocks();
        }
        return msg.data[offset + i:offset + len];
    }

    /// @notice Return the unread bounded command state without consuming it.
    function rawState(Execution memory exec) internal pure returns (bytes calldata) {
        return raw(exec, Lanes.State);
    }

    /// @notice Return the unread state lane and mark it fully consumed.
    /// @dev Intended for commands that forward their remaining state without decoding it.
    /// A lane declared EMPTY is returned empty and remains unconsumed so close
    /// still rejects any state supplied against the descriptor.
    function takeRawState(Execution memory exec) internal pure returns (bytes calldata data) {
        data = raw(exec, Lanes.State);
        if (!exec.decoders.contains(Lanes.State)) return data;

        uint cur = exec.decoders.select(Lanes.State);
        if (uint8(cur >> 96) == 0) return data;
        (, , uint len) = cur.decode();
        exec.decoders = cur.seek(len);
    }

    /// @notice Return the unread bounded endpoint input without consuming it.
    function rawInput(Execution memory exec) internal pure returns (bytes calldata) {
        return raw(exec, Lanes.Input);
    }

    /// @notice Return the unread input lane and mark it fully consumed.
    /// @dev Intended for endpoints that forward their remaining input without decoding it.
    /// A lane declared EMPTY is returned empty and remains unconsumed so close
    /// still rejects any input supplied against the descriptor.
    function takeRawInput(Execution memory exec) internal pure returns (bytes calldata data) {
        data = raw(exec, Lanes.Input);
        if (!exec.decoders.contains(Lanes.Input)) return data;

        uint cur = exec.decoders.select(Lanes.Input);
        if (uint8(cur >> 96) == 0) return data;
        (, , uint len) = cur.decode();
        exec.decoders = cur.seek(len);
    }

    /// @notice Return whether the next block on `lane` has `key` and an empty payload.
    /// @param exec Execution whose decoder is inspected without advancing.
    /// @param key Expected block key.
    /// @return Whether a complete matching empty block header occurs next.
    function isEmpty(Execution memory exec, bytes4 key) internal pure returns (bool) {
        uint cur = exec.decoders;
        (uint i, uint offset, uint len) = cur.decode();
        return Blocks.isEmpty(offset + i, offset + len, key);
    }

    /// @notice Validate and consume the next block from an execution decoder lane.
    /// @param exec Execution whose active decoder cursor is advanced over the complete block.
    /// @param spec Expected block specification.
    /// @return body Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function consume(Execution memory exec, uint spec) internal pure returns (uint body, uint end) {
        uint cur = exec.decoders;
        (body, end) = Blocks.enter(cur.absolute(), spec);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Validate a known key and consume the next block from an execution decoder lane.
    /// @dev Validates no payload-size constraint beyond proving the complete block
    /// lies within the active lane's logical region.
    /// @param exec Execution whose active decoder cursor is advanced over the complete block.
    /// @param key Expected block key.
    /// @return body Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function consume(Execution memory exec, bytes4 key) internal pure returns (uint body, uint end) {
        uint cur = exec.decoders;
        (body, end) = Blocks.enter(cur.absolute(), key);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Validate and consume one block from a decoder lane, returning its complete encoding.
    /// @param exec Execution whose active decoder cursor is advanced past the block.
    /// @param key Expected block key.
    /// @return data Calldata view of the complete block, including its header.
    function takeBlock(
        Execution memory exec,
        bytes4 key
    ) internal pure returns (bytes calldata data) {
        (uint abs, uint end) = consume(exec, key);
        data = msg.data[abs - Sizes.Header:end];
    }

    /// @notice Consume a matching empty block from an execution decoder lane when present.
    /// @param exec Execution whose active decoder advances only for a matching empty block.
    /// @param key Expected block key.
    /// @return Whether an empty block was consumed.
    function tryConsumeEmpty(Execution memory exec, bytes4 key) internal pure returns (bool) {
        uint cur = exec.decoders;
        (uint i, uint offset, uint size) = cur.decode();
        (bytes4 current, uint len) = Blocks.peek(offset + i, offset + size);
        if (current != key || len != 0) return false;
        exec.decoders = cur.seek(i + Sizes.Header);
        return true;
    }

    /// @notice Validate and enter the payload of the next block in an execution decoder lane.
    /// @dev The active lane remains in its existing frame so callers can decode
    /// child blocks in place. Callers should prove complete payload consumption
    /// with `exec.expectAbs(end)` after decoding the children from the same lane.
    /// @param exec Execution whose active decoder cursor advances over the block header.
    /// @param spec Expected parent block specification.
    /// @return body Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function enter(Execution memory exec, uint spec) internal pure returns (uint body, uint end) {
        return enter(exec, spec, 0);
    }

    /// @notice Validate and enter the payload of the next keyed block on an execution lane.
    /// @dev Validates no payload-size constraint. Callers should prove complete
    /// payload consumption with `exec.expectAbs(end)` after decoding.
    /// @param exec Execution whose active decoder advances over the block header.
    /// @param key Expected parent block key.
    /// @return body Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function enter(Execution memory exec, bytes4 key) internal pure returns (uint body, uint end) {
        return enter(exec, key, 0);
    }

    /// @notice Validate a parent block and advance over a fixed payload prefix.
    /// @dev `amount` is relative to the payload start and cannot exceed the
    /// current parent payload. The returned `abs` remains the payload start.
    /// @param exec Execution whose active decoder advances over the header and fixed prefix.
    /// @param spec Expected parent block specification.
    /// @param amount Number of initial payload bytes to advance over.
    /// @return body Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function enter(
        Execution memory exec,
        uint spec,
        uint amount
    ) internal pure returns (uint body, uint end) {
        uint cur = exec.decoders;
        uint next;
        (body, next, end) = Blocks.enter(cur.absolute(), spec, amount);
        exec.decoders = cur.seekAbs(next);
    }

    /// @notice Validate a keyed parent block and advance over a fixed payload prefix.
    /// @dev Validates no payload-size constraint beyond the requested prefix.
    /// The returned `body` remains the payload start.
    /// @param exec Execution whose active decoder advances over the header and fixed prefix.
    /// @param key Expected parent block key.
    /// @param amount Number of initial payload bytes to advance over.
    /// @return body Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function enter(
        Execution memory exec,
        bytes4 key,
        uint amount
    ) internal pure returns (uint body, uint end) {
        uint cur = exec.decoders;
        uint next;
        (body, next, end) = Blocks.enter(cur.absolute(), key, amount);
        exec.decoders = cur.seekAbs(next);
    }

    /// @notice Advance an execution decoder lane by a raw byte count.
    /// @dev No block header or schema is validated.
    /// @param exec Execution whose active decoder cursor is advanced.
    /// @param amount Number of bytes to advance.
    function advance(Execution memory exec, uint amount) internal pure {
        uint cur = exec.decoders;
        exec.decoders = cur.advance(amount);
    }

    /// @notice Take a raw byte range from an execution decoder lane.
    /// @dev No block header or schema is validated.
    /// @param exec Execution whose active decoder cursor is advanced.
    /// @param amount Number of bytes to take.
    /// @return abs Absolute position of the first taken byte.
    function take(Execution memory exec, uint amount) internal pure returns (uint abs) {
        (exec.decoders, abs) = exec.decoders.consume(amount);
    }

    /// @notice Require the active execution decoder to be at absolute position `abs`.
    /// @dev `oninput()` and `onstate()` determine the active lane.
    /// @param exec Execution whose active decoder position is validated.
    /// @param abs Expected absolute position.
    function expectAbs(Execution memory exec, uint abs) internal pure {
        exec.decoders.expectAbs(abs);
    }

    /// @notice Consume a LIST block and return a cursor scoped to its payload.
    /// @param exec Execution whose decoder is advanced.
    /// @return items Cursor over the nested list items.
    function list(Execution memory exec) internal pure returns (Cur memory items) {
        return list(exec, Specs.List);
    }

    /// @notice Consume a list block described by `spec` and return a cursor scoped to its payload.
    /// @param exec Execution whose decoder is advanced.
    /// @param spec Custom list block specification.
    /// @return items Cursor over the nested list items.
    function list(Execution memory exec, uint spec) internal pure returns (Cur memory items) {
        (uint abs, uint end) = consume(exec, spec);
        items.state = Cursors.create(abs, end - abs, 0, 0, 0);
    }

    // -------------------------------------------------------------------------
    // Fixed-width block decoding
    // -------------------------------------------------------------------------

    /// @dev Return the next raw calldata word from the active lane and advance by `size` bytes.
    function nextN(Execution memory exec, uint size) private pure returns (bytes32 value) {
        value = Blocks.read32(take(exec, size));
    }

    /// @notice Return the next raw byte from a decoder lane and advance it by one byte.
    function next1(Execution memory exec) internal pure returns (bytes1 value) {
        value = bytes1(nextN(exec, 1));
    }

    /// @notice Return the next two raw bytes from a decoder lane and advance it by two bytes.
    function next2(Execution memory exec) internal pure returns (bytes2 value) {
        value = bytes2(nextN(exec, 2));
    }

    /// @notice Return the next four raw bytes from a decoder lane and advance it by four bytes.
    function next4(Execution memory exec) internal pure returns (bytes4 value) {
        value = bytes4(nextN(exec, 4));
    }

    /// @notice Return the next eight raw bytes from a decoder lane and advance it by eight bytes.
    function next8(Execution memory exec) internal pure returns (bytes8 value) {
        value = bytes8(nextN(exec, 8));
    }

    /// @notice Return the next sixteen raw bytes from a decoder lane and advance it by sixteen bytes.
    function next16(Execution memory exec) internal pure returns (bytes16 value) {
        value = bytes16(nextN(exec, 16));
    }

    /// @notice Return the next raw calldata word from a decoder lane and advance it.
    /// @param exec Execution whose active decoder cursor advances by one word.
    /// @return value Raw word at the active lane's previous position.
    function next32(Execution memory exec) internal pure returns (bytes32 value) {
        value = nextN(exec, Sizes.Word);
    }

    /// @notice Decode one fixed 32-byte payload from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @param spec Expected fixed block specification.
    /// @return value Decoded payload word.
    function unpack32(Execution memory exec, uint spec) internal pure returns (bytes32 value) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.B32);
        if (Blocks.header(abs, Specs.key(spec)) != 32) revert Blocks.InvalidBlock();
        assembly ("memory-safe") {
            value := calldataload(add(abs, 0x08))
        }
    }

    /// @notice Decode and consume one ACCOUNT block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return account Decoded account identifier.
    function unpackAccount(Execution memory exec) internal pure returns (bytes32 account) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.B32);
        account = Blocks.unpackAccount(abs);
    }

    /// @notice Decode and consume one NODE block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return node Decoded node identifier.
    function unpackNode(Execution memory exec) internal pure returns (uint node) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.B32);
        node = Blocks.unpackNode(abs);
    }

    /// @notice Decode and consume one BOOTSTRAP block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded balance amount.
    /// @return budget Decoded native-value budget contribution.
    function unpackBootstrap(
        Execution memory exec
    ) internal pure returns (bytes32 asset, uint amount, uint budget) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.Bootstrap);
        return Blocks.unpackBootstrap(abs);
    }

    /// @notice Decode and consume one ASSET block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return asset Decoded asset identifier.
    function unpackAsset(Execution memory exec) internal pure returns (bytes32 asset) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.B32);
        asset = Blocks.unpackAsset(abs);
    }

    /// @notice Decode and consume one ACCOUNT_ASSET block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    function unpackAccountAsset(Execution memory exec) internal pure returns (bytes32 account, bytes32 asset) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.B64);
        (account, asset) = Blocks.unpackAccountAsset(abs);
    }

    /// @notice Decode one ACCOUNT_ASSET block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @return value Decoded account and asset.
    function unpackAccountAssetValue(Execution memory exec) internal pure returns (AccountAsset memory value) {
        (value.account, value.asset) = unpackAccountAsset(exec);
    }

    /// @notice Decode and consume one HOST_ASSET block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    function unpackHostAsset(Execution memory exec) internal pure returns (uint host, bytes32 asset) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.HostAsset);
        (host, asset) = Blocks.unpackHostAsset(abs);
    }

    /// @notice Decode one HOST_ASSET block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @return value Decoded host and asset.
    function unpackHostAssetValue(Execution memory exec) internal pure returns (HostAsset memory value) {
        (value.host, value.asset) = unpackHostAsset(exec);
    }

    /// @notice Decode and consume one AMOUNT block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
    function unpackAmount(Execution memory exec) internal pure returns (bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.Amount);
        (asset, amount) = Blocks.unpackAmount(abs);
    }

    /// @notice Decode one AMOUNT block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @return value Decoded asset and amount.
    function unpackAmountValue(Execution memory exec) internal pure returns (AssetAmount memory value) {
        (value.asset, value.amount) = unpackAmount(exec);
    }

    /// @notice Decode and consume one BALANCE block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded balance amount.
    function unpackBalance(Execution memory exec) internal pure returns (bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.Balance);
        (asset, amount) = Blocks.unpackBalance(abs);
    }

    /// @notice Decode one BALANCE block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @return value Decoded asset and balance amount.
    function unpackBalanceValue(Execution memory exec) internal pure returns (AssetAmount memory value) {
        (value.asset, value.amount) = unpackBalance(exec);
    }

    /// @notice Decode and consume one DEBT block from the active lane.
    function unpackDebt(Execution memory exec) internal pure returns (bytes32 liability, uint debt) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.Debt);
        (liability, debt) = Blocks.unpackDebt(abs);
    }

    /// @notice Decode one DEBT block into its structured value.
    function unpackDebtValue(Execution memory exec) internal pure returns (Debt memory value) {
        (value.liability, value.debt) = unpackDebt(exec);
    }

    /// @notice Decode and consume one POSITION block from the active lane.
    function unpackPosition(Execution memory exec) internal pure returns (bytes32 asset, uint amount, bytes32 liability, uint debt) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.Position);
        (asset, amount, liability, debt) = Blocks.unpackPosition(abs);
    }

    /// @notice Decode one POSITION block into its structured value.
    function unpackPositionValue(Execution memory exec) internal pure returns (Position memory value) {
        (value.asset, value.amount, value.liability, value.debt) = unpackPosition(exec);
    }

    /// @notice Decode one BALANCE block and associate it with `host`.
    /// @param exec Execution whose decoder is advanced.
    /// @param host Host associated with the decoded balance.
    /// @return value Host-scoped asset amount.
    function unpackBalanceForHost(
        Execution memory exec,
        uint host
    ) internal pure returns (HostAmount memory value) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.Balance);
        value.host = host;
        (value.asset, value.amount) = Blocks.unpackBalance(abs);
    }

    /// @notice Decode and consume one ACCOUNT_AMOUNT block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
    function unpackAccountAmount(Execution memory exec) internal pure returns (bytes32 account, bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.B96);
        (account, asset, amount) = Blocks.unpackAccountAmount(abs);
    }

    /// @notice Decode one ACCOUNT_AMOUNT block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @return value Decoded account, asset, and amount.
    function unpackAccountAmountValue(Execution memory exec) internal pure returns (AccountAmount memory value) {
        (value.account, value.asset, value.amount) = unpackAccountAmount(exec);
    }

    /// @notice Decode and consume one ALLOCATION block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
    function unpackAllocation(Execution memory exec) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.B96);
        (host, asset, amount) = Blocks.unpackAllocation(abs);
    }

    /// @notice Decode one ALLOCATION block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @return value Decoded host, asset, and amount.
    function unpackAllocationValue(Execution memory exec) internal pure returns (HostAmount memory value) {
        (value.host, value.asset, value.amount) = unpackAllocation(exec);
    }

    /// @notice Decode and consume one ALLOWANCE block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded allowance amount.
    function unpackAllowance(Execution memory exec) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.B96);
        (host, asset, amount) = Blocks.unpackAllowance(abs);
    }

    /// @notice Decode one ALLOWANCE block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @return value Decoded host, asset, and allowance amount.
    function unpackAllowanceValue(Execution memory exec) internal pure returns (HostAmount memory value) {
        (value.host, value.asset, value.amount) = unpackAllowance(exec);
    }

    /// @notice Decode and consume one CUSTODY block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded custody amount.
    function unpackCustody(Execution memory exec) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.B96);
        (host, asset, amount) = Blocks.unpackCustody(abs);
    }

    /// @notice Decode one CUSTODY block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @return value Decoded host, asset, and custody amount.
    function unpackCustodyValue(Execution memory exec) internal pure returns (HostAmount memory value) {
        (value.host, value.asset, value.amount) = unpackCustody(exec);
    }

    /// @notice Decode and consume one HOST_ACCOUNT_ASSET block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return host Decoded host identifier.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    function unpackHostAccountAsset(Execution memory exec) internal pure returns (uint host, bytes32 account, bytes32 asset) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.B96);
        (host, account, asset) = Blocks.unpackHostAccountAsset(abs);
    }

    /// @notice Decode one HOST_ACCOUNT_ASSET block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @return value Decoded host, account, and asset.
    function unpackHostAccountAssetValue(Execution memory exec) internal pure returns (HostAccountAsset memory value) {
        (value.host, value.account, value.asset) = unpackHostAccountAsset(exec);
    }

    /// @notice Decode and consume one TRANSACTION block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return from Decoded debit account.
    /// @return to Decoded credit account.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded transaction amount.
    function unpackTransaction(Execution memory exec) internal pure returns (bytes32 from, bytes32 to, bytes32 asset, uint amount) {
        uint abs;
        (exec.decoders, abs) = exec.decoders.consume(Sizes.Transaction);
        (from, to, asset, amount) = Blocks.unpackTransaction(abs);
    }

    /// @notice Decode one TRANSACTION block into its structured value.
    /// @param exec Execution whose decoder is advanced.
    /// @return value Decoded transaction.
    function unpackTransactionValue(Execution memory exec) internal pure returns (Tx memory value) {
        (value.from, value.to, value.asset, value.amount) = unpackTransaction(exec);
    }

    // -------------------------------------------------------------------------
    // Dynamic block decoding
    // -------------------------------------------------------------------------

    /// @notice Decode and consume a block described by `spec` from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @param spec Expected block specification.
    /// @return data Calldata view of the decoded payload.
    function unpackRaw(Execution memory exec, uint spec) internal pure returns (bytes calldata data) {
        uint cur = exec.decoders;
        uint end;
        (data, end) = Blocks.unpackRaw(cur.absolute(), spec);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one BYTES block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return data Decoded byte payload.
    function unpackBytes(Execution memory exec) internal pure returns (bytes calldata data) {
        uint cur = exec.decoders;
        uint end;
        (data, end) = Blocks.unpackBytes(cur.absolute());
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one STRING block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return data Decoded string payload.
    function unpackString(Execution memory exec) internal pure returns (string memory data) {
        uint cur = exec.decoders;
        bytes calldata value;
        uint end;
        (value, end) = Blocks.unpackString(cur.absolute());
        exec.decoders = cur.seekAbs(end);
        data = string(value);
    }

    /// @notice Decode and consume one STEP block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return cmd Decoded command identifier.
    /// @return value Decoded native value.
    /// @return input Decoded nested input.
    function unpackStep(Execution memory exec) internal pure returns (uint cmd, uint value, bytes calldata input) {
        uint cur = exec.decoders;
        uint end;
        (cmd, value, input, end) = Blocks.unpackStep(cur.absolute());
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one CALL block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return target Decoded call target.
    /// @return resources Decoded packed resources.
    /// @return data Decoded call payload.
    function unpackCall(Execution memory exec) internal pure returns (uint target, uint resources, bytes calldata data) {
        uint cur = exec.decoders;
        uint abs = cur.absolute();
        uint end;
        (target, resources, data, end) = Blocks.unpackCall(abs);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one ANNOTATION block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return entity Decoded entity identifier.
    /// @return data Decoded annotation block stream.
    function unpackAnnotation(Execution memory exec) internal pure returns (uint entity, bytes calldata data) {
        uint cur = exec.decoders;
        uint end;
        (entity, data, end) = Blocks.unpackAnnotation(cur.absolute());
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one CONTEXT block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return account Decoded account identifier.
    /// @return state Decoded nested state.
    /// @return input Decoded nested input.
    function unpackContext(Execution memory exec) internal pure returns (bytes32 account, bytes calldata state, bytes calldata input) {
        uint cur = exec.decoders;
        uint abs = cur.absolute();
        uint end;
        (account, state, input, end) = Blocks.unpackContext(abs);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one RELAY block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return input Decoded nested input.
    /// @return steps Decoded remaining pipeline steps.
    function unpackRelay(Execution memory exec) internal pure returns (bytes calldata input, bytes calldata steps) {
        uint cur = exec.decoders;
        uint end;
        (input, steps, end) = Blocks.unpackRelay(cur.absolute());
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one DISPATCH block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return portal Decoded destination portal.
    /// @return resources Decoded packed resources.
    /// @return payload Decoded dispatch payload.
    function unpackDispatch(Execution memory exec) internal pure returns (uint portal, uint resources, bytes calldata payload) {
        uint cur = exec.decoders;
        uint abs = cur.absolute();
        uint end;
        (portal, resources, payload, end) = Blocks.unpackDispatch(abs);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one LABEL block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return namespace Decoded label namespace.
    /// @return name Decoded label text.
    function unpackLabel(Execution memory exec) internal pure returns (bytes32 namespace, string memory name) {
        uint cur = exec.decoders;
        uint abs = cur.absolute();
        uint end;
        (namespace, name, end) = Blocks.unpackLabel(abs);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one SCHEMA block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return spec Decoded block specification.
    /// @return body Decoded schema body.
    /// @return name Decoded schema name.
    function unpackSchema(Execution memory exec) internal pure returns (uint spec, string memory body, bytes32 name) {
        uint cur = exec.decoders;
        uint abs = cur.absolute();
        uint end;
        (spec, body, name, end) = Blocks.unpackSchema(abs);
        exec.decoders = cur.seekAbs(end);
    }

    /// @notice Decode and consume one RECOVER block from the active lane.
    /// @param exec Execution whose decoder is advanced.
    /// @return handler Decoded recovery handler.
    /// @return resources Decoded packed resources.
    /// @return key Decoded recovery key.
    /// @return witness Decoded recovery witness.
    function unpackRecover(Execution memory exec) internal pure returns (uint handler, uint resources, bytes32 key, bytes calldata witness) {
        uint cur = exec.decoders;
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
        (exec.writer, exec.output, i) = Buffers.reserve(exec.writer, exec.output, amount, touch);
    }

    /// @dev Reserve an exact number of output bytes.
    /// @param exec Execution whose output writer is advanced.
    /// @param size Number of bytes to reserve and touch.
    /// @return i Relative output offset reserved for the write.
    function reserve(Execution memory exec, uint size) private pure returns (uint i) {
        (exec.writer, exec.output, i) = Buffers.reserve(exec.writer, exec.output, size, size);
    }

    /// @notice Append an empty block to execution output.
    /// @param exec Execution receiving the block.
    /// @param key Block key.
    function outputEmpty(Execution memory exec, bytes4 key) internal pure {
        uint i = reserve(exec, Sizes.Header);
        Blocks.writeEmpty(exec.output, i, key);
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

    /// @notice Append a DEBT block to execution output.
    function outputDebt(Execution memory exec, bytes32 liability, uint debt) internal pure {
        uint i = reserve(exec, Sizes.Debt);
        Blocks.writeDebt(exec.output, i, liability, debt);
    }

    /// @notice Append a structured DEBT value to execution output.
    function outputDebt(Execution memory exec, Debt memory value) internal pure {
        outputDebt(exec, value.liability, value.debt);
    }

    /// @notice Append a POSITION block to execution output.
    function outputPosition(
        Execution memory exec,
        bytes32 asset,
        uint amount,
        bytes32 liability,
        uint debt
    ) internal pure {
        uint i = reserve(exec, Sizes.Position);
        Blocks.writePosition(exec.output, i, asset, amount, liability, debt);
    }

    /// @notice Append a structured POSITION value to execution output.
    function outputPosition(Execution memory exec, Position memory value) internal pure {
        outputPosition(exec, value.asset, value.amount, value.liability, value.debt);
    }

    /// @notice Append an ACCOUNT_ASSET block to execution output.
    /// @param exec Execution receiving the block.
    /// @param account Account identifier to encode.
    /// @param asset Asset identifier to encode.
    function outputAccountAsset(Execution memory exec, bytes32 account, bytes32 asset) internal pure {
        uint i = reserve(exec, Sizes.B64);
        Blocks.writeAccountAsset(exec.output, i, account, asset);
    }

    /// @notice Append a HOST_ASSET block to execution output.
    /// @param exec Execution receiving the block.
    /// @param host Host identifier to encode.
    /// @param asset Asset identifier to encode.
    function outputHostAsset(Execution memory exec, uint host, bytes32 asset) internal pure {
        uint i = reserve(exec, Sizes.HostAsset);
        Blocks.writeHostAsset(exec.output, i, host, asset);
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
    /// @param value Native value to encode.
    /// @param input Command input to encode.
    function outputStep(Execution memory exec, uint cmd, uint value, bytes memory input) internal pure {
        uint size = Sizes.Step + input.length;
        uint i = reserve(exec, size);
        Blocks.writeStep(exec.output, i, cmd, value, input);
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
    /// @param input Relay input to encode.
    /// @param steps Remaining pipeline steps to encode.
    function outputRelay(Execution memory exec, bytes memory input, bytes memory steps) internal pure {
        uint size = 3 * Sizes.Header + input.length + steps.length;
        uint i = reserve(exec, size);
        Blocks.writeRelay(exec.output, i, input, steps);
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
    /// @param namespace Label namespace to encode.
    /// @param name Label text to encode.
    function outputLabel(Execution memory exec, bytes32 namespace, string memory name) internal pure {
        uint size = Sizes.B32 + Sizes.Header + bytes(name).length;
        uint i = reserve(exec, size);
        Blocks.writeLabel(exec.output, i, namespace, name);
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
    // Calldata output copy helpers
    // -------------------------------------------------------------------------

    /// @notice Append a custom block to execution output by copying its payload from calldata.
    function outputCopyBlock(Execution memory exec, uint spec, bytes calldata data) internal pure {
        Specs.validate(spec, data.length);
        uint size = Sizes.Header + data.length;
        uint i = reserve(exec, size);
        Blocks.copy(exec.output, i, Specs.key(spec), data);
    }

    /// @notice Append a LIST block to execution output by copying its payload from calldata.
    function outputCopyList(Execution memory exec, bytes calldata value) internal pure {
        uint size = Sizes.Header + value.length;
        uint i = reserve(exec, size);
        Blocks.copyList(exec.output, i, value);
    }

    /// @notice Append a BYTES block to execution output by copying its payload from calldata.
    function outputCopyBytes(Execution memory exec, bytes calldata value) internal pure {
        uint size = Sizes.Header + value.length;
        uint i = reserve(exec, size);
        Blocks.copyBytes(exec.output, i, value);
    }

    /// @notice Append a STRING block to execution output by copying its payload from calldata.
    function outputCopyString(Execution memory exec, string calldata value) internal pure {
        uint size = Sizes.Header + bytes(value).length;
        uint i = reserve(exec, size);
        Blocks.copyString(exec.output, i, value);
    }

    /// @notice Append a STEP block to execution output by copying its nested input from calldata.
    function outputCopyStep(Execution memory exec, uint cmd, uint value, bytes calldata input) internal pure {
        uint size = Sizes.Step + input.length;
        uint i = reserve(exec, size);
        Blocks.copyStep(exec.output, i, cmd, value, input);
    }

    /// @notice Append a CALL block to execution output by copying its nested payload from calldata.
    function outputCopyCall(Execution memory exec, uint target, uint resources, bytes calldata payload) internal pure {
        uint size = Sizes.B64 + Sizes.Header + payload.length;
        uint i = reserve(exec, size);
        Blocks.copyCall(exec.output, i, target, resources, payload);
    }

    /// @notice Append a RELAY block to execution output by copying its nested streams from calldata.
    function outputCopyRelay(Execution memory exec, bytes calldata input, bytes calldata steps) internal pure {
        uint size = 3 * Sizes.Header + input.length + steps.length;
        uint i = reserve(exec, size);
        Blocks.copyRelay(exec.output, i, input, steps);
    }

    /// @notice Append a DISPATCH block to execution output by copying its nested payload from calldata.
    function outputCopyDispatch(Execution memory exec, uint portal, uint resources, bytes calldata payload) internal pure {
        uint size = Sizes.B64 + Sizes.Header + payload.length;
        uint i = reserve(exec, size);
        Blocks.copyDispatch(exec.output, i, portal, resources, payload);
    }

    /// @notice Append a CONTEXT block to execution output by copying its nested streams from calldata.
    function outputCopyContext(
        Execution memory exec,
        bytes32 account,
        bytes calldata state,
        bytes calldata input
    ) internal pure {
        uint size = Sizes.B32 + 2 * Sizes.Header + state.length + input.length;
        uint i = reserve(exec, size);
        Blocks.copyContext(exec.output, i, account, state, input);
    }

    /// @notice Append a RECOVER block to execution output by copying its nested witness from calldata.
    function outputCopyRecover(
        Execution memory exec,
        uint handler,
        uint resources,
        bytes32 recoverykey,
        bytes calldata witness
    ) internal pure {
        uint size = Sizes.B96 + Sizes.Header + witness.length;
        uint i = reserve(exec, size);
        Blocks.copyRecover(exec.output, i, handler, resources, recoverykey, witness);
    }

    // -------------------------------------------------------------------------
    // Value
    // -------------------------------------------------------------------------

    /// @notice Remove and return the remaining execution value budget.
    /// @param exec Execution whose budget is drained.
    /// @return budget Native value removed from the execution.
    function drainBudget(Execution memory exec) internal pure returns (uint budget) {
        budget = exec.budget;
        exec.budget = 0;
    }

    /// @notice Transfer the remaining value budget out of an execution.
    /// @dev Clears `exec.budget` so the returned budget becomes its sole owner.
    /// @param exec Execution whose budget is detached.
    /// @return budget Detached budget containing the remaining value.
    function takeBudget(Execution memory exec) internal pure returns (Budget memory budget) {
        budget.remaining = drainBudget(exec);
    }

    /// @notice Deduct an exact native value from the execution budget.
    /// @param exec Mutable execution whose budget is charged.
    /// @param value Native value to consume in wei.
    /// @return The consumed native value.
    function useValue(Execution memory exec, uint value) internal pure returns (uint) {
        if (value > exec.budget) revert InsufficientValue();
        exec.budget -= value;
        return value;
    }

    /// @notice Deduct the EVM value lane of `resources` from the execution budget.
    /// @dev `resources` is not a native value. This helper explicitly extracts
    /// its low 128-bit EVM value lane and widens that lane to a plain `uint`.
    /// @param exec Mutable execution whose budget is charged.
    /// @param resources Packed resources whose value lane should be spent.
    /// @return value Native value to forward in wei.
    function useResourceValue(Execution memory exec, uint resources) internal pure returns (uint value) {
        value = uint128(resources);
        useValue(exec, value);
    }

    // -------------------------------------------------------------------------
    // Finalization
    // -------------------------------------------------------------------------

    /// @notice Finalize and return regular execution output.
    /// @param exec Execution whose output is finalized.
    /// @return out Trimmed output bytes.
    function finish(Execution memory exec) internal pure returns (bytes memory out) {
        if (exec.decoders.any()) revert UnconsumedData();
        if (exec.output.length == 0) return new bytes(0);

        out = Buffers.finish(exec.writer, exec.output);
    }

    /// @notice Close an execution and return its output and remaining budget.
    /// @param exec Execution whose lanes, writer, and budget are finalized.
    /// @return output Final encoded output block stream.
    /// @return credit Remaining native value to credit to the caller's budget.
    function close(Execution memory exec) internal pure returns (bytes memory output, uint credit) {
        return close(exec, 0);
    }

    /// @notice Close an execution and combine its remaining budget with additional command credit.
    /// @param exec Execution whose lanes, writer, and budget are finalized.
    /// @param extraCredit Additional trusted credit produced by the command.
    /// @return output Final encoded output block stream.
    /// @return credit Remaining execution budget plus `extraCredit`.
    function close(
        Execution memory exec,
        uint extraCredit
    ) internal pure returns (bytes memory output, uint credit) {
        output = finish(exec);
        credit = exec.budget + extraCredit;
        exec.budget = 0;
    }

}
