// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AssetAmount, AccountAsset, HostAsset, AccountAmount, HostAmount, HostAccountAsset, Debt, Position, Tx} from "../core/Types.sol";
import {Blocks} from "./Blocks.sol";
import {Sizes, Specs} from "./Specs.sol";
import {Cursors, Cur} from "../utils/Cursors.sol";
import {UnconsumedData} from "../utils/Errors.sol";

using Decoders for Cur;

/// @title Decoders
/// @notice Mutable calldata block decoding through a Cur memory cursor.
library Decoders {
    using Cursors for uint;

    // -------------------------------------------------------------------------
    // Cur memory adapters
    // -------------------------------------------------------------------------

    /// @notice Open a calldata source without inspecting its contents.
    /// @param source Calldata region to open.
    /// @return cur Cursor spanning the complete source.
    function open(bytes calldata source) internal pure returns (Cur memory cur) {
        cur.state = Cursors.wrap(source, 0);
    }

    /// @notice Return whether `cur` has unread bytes.
    /// @param cur Cursor to inspect.
    /// @return Whether unread bytes remain.
    function more(Cur memory cur) internal pure returns (bool) {
        return cur.state.more();
    }

    /// @notice Require the complete decoder source to have been consumed.
    /// @param cur Decoder cursor to close.
    function close(Cur memory cur) internal pure {
        if (cur.state.more()) revert UnconsumedData();
    }

    /// @notice Return the cursor's current absolute calldata position.
    /// @param cur Cursor to inspect.
    /// @return Current absolute calldata position.
    function absolute(Cur memory cur) internal pure returns (uint) {
        return cur.state.absolute();
    }

    /// @notice Validate and consume the next block from a cursor.
    /// @param cur Cursor advanced over the complete block.
    /// @param spec Expected block specification.
    /// @return abs Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function consume(Cur memory cur, uint spec) internal pure returns (uint abs, uint end) {
        (abs, end) = Blocks.expect(cur.state.absolute(), spec);
        cur.state = cur.state.seekAbs(end);
    }

    /// @notice Validate a known key and consume the next block from a cursor.
    /// @dev Validates no payload-size constraint beyond proving the complete block
    /// lies within the cursor's logical region.
    /// @param cur Cursor advanced over the complete block.
    /// @param key Expected block key.
    /// @return abs Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function consume(Cur memory cur, bytes4 key) internal pure returns (uint abs, uint end) {
        (abs, end) = Blocks.expectKey(cur.state.absolute(), key);
        cur.state = cur.state.seekAbs(end);
    }

    /// @notice Consume a matching empty block from a cursor when present.
    /// @param cur Cursor advanced only when the matching block is empty.
    /// @param key Expected block key.
    /// @return Whether an empty block was consumed.
    function tryConsumeEmpty(Cur memory cur, bytes4 key) internal pure returns (bool) {
        (uint i, uint offset, uint size) = cur.state.decode();
        (bytes4 current, uint len) = Blocks.peek(offset + i, offset + size);
        if (current != key || len != 0) return false;
        cur.state = cur.state.seek(i + Sizes.Header);
        return true;
    }

    /// @notice Validate and enter the payload of the next block in a cursor.
    /// @dev The cursor remains in its existing frame so callers can decode child
    /// blocks in place. Callers should prove complete payload consumption with
    /// `cur.state.expectAbs(end)` after decoding the children.
    /// @param cur Cursor advanced over the block header to its payload.
    /// @param spec Expected parent block specification.
    /// @return abs Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function enter(Cur memory cur, uint spec) internal pure returns (uint abs, uint end) {
        return enter(cur, spec, 0);
    }

    /// @notice Validate a parent block and advance over a fixed payload prefix.
    /// @dev `amount` is relative to the payload start and cannot exceed the
    /// current parent payload. The returned `abs` remains the payload start.
    /// @param cur Cursor advanced over the block header and fixed prefix.
    /// @param spec Expected parent block specification.
    /// @param amount Number of initial payload bytes to advance over.
    /// @return abs Absolute position of the first payload byte.
    /// @return end Absolute position immediately after the payload.
    function enter(Cur memory cur, uint spec, uint amount) internal pure returns (uint abs, uint end) {
        (abs, end) = Blocks.expect(cur.state.absolute(), spec);
        if (amount > end - abs) revert Blocks.InvalidBlock();
        cur.state = cur.state.seekAbs(abs + amount);
    }

    /// @notice Advance a cursor by a raw byte count.
    /// @dev No block header or schema is validated.
    /// @param cur Cursor advanced by `amount` bytes.
    /// @param amount Number of bytes to advance.
    function advance(Cur memory cur, uint amount) internal pure {
        cur.state = cur.state.advance(amount);
    }

    /// @notice Take a raw byte range from the cursor.
    /// @dev No block header or schema is validated.
    /// @param cur Cursor advanced by `amount` bytes.
    /// @param amount Number of bytes to take.
    /// @return abs Absolute position of the first taken byte.
    function take(Cur memory cur, uint amount) internal pure returns (uint abs) {
        (cur.state, abs) = cur.state.consume(amount);
    }

    /// @notice Require a decoder cursor to be at absolute position `abs`.
    /// @param cur Cursor whose position is validated.
    /// @param abs Expected absolute position.
    function expectAbs(Cur memory cur, uint abs) internal pure {
        cur.state.expectAbs(abs);
    }

    /// @notice Create a child cursor over relative range `[from, to)`.
    /// @param cur Parent cursor.
    /// @param from Inclusive relative start.
    /// @param to Exclusive relative end.
    /// @return out Child cursor spanning the selected range.
    function slice(Cur memory cur, uint from, uint to) internal pure returns (Cur memory out) {
        out.state = cur.state.slice(from, to, 0);
    }

    /// @notice Return the complete calldata region represented by `cur`.
    /// @param cur Cursor whose calldata is returned.
    /// @return Complete cursor region.
    function raw(Cur memory cur) internal pure returns (bytes calldata) {
        (uint abs, uint end) = cur.state.bounds();
        if (end > msg.data.length) revert Blocks.MalformedBlocks();
        return msg.data[abs:end];
    }

    /// @notice Return relative calldata range `[from, to)` from `cur`.
    /// @param cur Cursor containing the range.
    /// @param from Inclusive relative start.
    /// @param to Exclusive relative end.
    /// @return data Selected calldata range.
    function raw(Cur memory cur, uint from, uint to) internal pure returns (bytes calldata data) {
        (, uint offset, uint len) = cur.state.decode();
        if (from > to || to > len) revert Blocks.MalformedBlocks();
        if (len > msg.data.length || offset > msg.data.length - len) revert Blocks.MalformedBlocks();
        data = msg.data[offset + from:offset + to];
    }

    /// @notice Hash relative calldata range `[from, to)` from `cur`.
    /// @param cur Cursor containing the range.
    /// @param from Inclusive relative start.
    /// @param to Exclusive relative end.
    /// @return Hash of the selected calldata.
    function hash(Cur memory cur, uint from, uint to) internal pure returns (bytes32) {
        return keccak256(raw(cur, from, to));
    }

    /// @notice Read the block header at relative position `i` without advancing.
    /// @param cur Cursor containing the block.
    /// @param i Relative block position.
    /// @return key Block key.
    /// @return len Payload length.
    function peek(Cur memory cur, uint i) internal pure returns (bytes4 key, uint len) {
        (, uint offset, uint size) = cur.state.decode();
        return Blocks.peek(offset + i, offset + size);
    }

    /// @notice Return the relative position immediately after the current block.
    /// @param cur Cursor positioned at a block.
    /// @return Relative position after the block.
    function past(Cur memory cur) internal pure returns (uint) {
        (uint i, , ) = cur.state.decode();
        (, uint len) = peek(cur, i);
        return i + Sizes.Header + len;
    }

    /// @notice Return whether `key` occurs at relative position `i`.
    /// @param cur Cursor containing the position.
    /// @param i Relative block position.
    /// @param key Expected block key.
    /// @return Whether the key occurs at the position.
    function hasAt(Cur memory cur, uint i, bytes4 key) internal pure returns (bool) {
        (, uint offset, uint len) = cur.state.decode();
        return Blocks.hasAt(offset + i, offset + len, key);
    }

    /// @notice Return whether the current block has `key`.
    /// @param cur Cursor positioned at a block.
    /// @param key Expected block key.
    /// @return Whether the current block has the key.
    function isAt(Cur memory cur, bytes4 key) internal pure returns (bool) {
        (uint i, uint offset, uint len) = cur.state.decode();
        return Blocks.hasAt(offset + i, offset + len, key);
    }

    /// @notice Return whether the current block has `key` and an empty payload.
    /// @param cur Cursor positioned at a block.
    /// @param key Expected block key.
    /// @return Whether a complete matching empty block header occurs at the current position.
    function isEmpty(Cur memory cur, bytes4 key) internal pure returns (bool) {
        (uint i, uint offset, uint len) = cur.state.decode();
        return Blocks.isEmpty(offset + i, offset + len, key);
    }

    /// @notice Find `key` at or after relative position `i`.
    /// @param cur Cursor to search.
    /// @param i Relative search position.
    /// @param key Block key to find.
    /// @return Relative position of the matching block.
    function find(Cur memory cur, uint i, bytes4 key) internal pure returns (uint) {
        (, uint offset, uint end) = cur.state.decode();
        return Blocks.find(offset + i, offset + end, key) - offset;
    }

    /// @notice Find `key` at or after the current cursor position.
    /// @param cur Cursor to search from its current position.
    /// @param key Block key to find.
    /// @return Relative position of the matching block.
    function find(Cur memory cur, bytes4 key) internal pure returns (uint) {
        (uint i, uint offset, uint end) = cur.state.decode();
        return Blocks.find(offset + i, offset + end, key) - offset;
    }

    /// @notice Count consecutive blocks with `key` from the current cursor position.
    /// @dev Does not advance the cursor.
    /// @param cur Cursor to inspect.
    /// @param key Block key forming the run.
    /// @return count Number of consecutive matching blocks.
    function run(Cur memory cur, bytes4 key) internal pure returns (uint count) {
        (uint i, uint offset, uint len) = cur.state.decode();
        (count, ) = Blocks.run(offset + i, offset + len, key);
    }

    /// @notice Consume one LIST block and return a cursor over its items.
    /// @param cur Cursor advanced past the list.
    /// @return items Cursor spanning the list payload.
    function list(Cur memory cur) internal pure returns (Cur memory items) {
        return list(cur, Specs.List);
    }

    /// @notice Consume a list block described by `spec` and return a cursor over its items.
    /// @param cur Cursor advanced past the list.
    /// @param spec Custom list block specification.
    /// @return items Cursor spanning the list payload.
    function list(Cur memory cur, uint spec) internal pure returns (Cur memory items) {
        (uint abs, uint end) = consume(cur, spec);
        items.state = Cursors.create(abs, end - abs, 0, 0, 0);
    }

    /// @notice Consume one block with `key` and return its complete encoded region.
    /// @param cur Cursor advanced past the block.
    /// @param key Expected block key.
    /// @return out Cursor spanning the complete encoded block.
    function takeBlock(Cur memory cur, bytes4 key) internal pure returns (Cur memory out) {
        uint abs = cur.state.absolute();
        (, uint end) = consume(cur, key);
        out.state = Cursors.create(abs, end - abs, 0, 0, 0);
    }

    // -------------------------------------------------------------------------
    // Generic block decoding
    // -------------------------------------------------------------------------

    /// @notice Decode and consume a block described by `spec`.
    /// @param cur Cursor advanced past the block.
    /// @param spec Expected block specification.
    /// @return data Decoded payload.
    function unpackRaw(Cur memory cur, uint spec) internal pure returns (bytes calldata data) {
        uint end;
        (data, end) = Blocks.unpackRaw(cur.state.absolute(), spec);
        cur.state = cur.state.seekAbs(end);
    }

    /// @notice Decode and consume one BYTES block.
    /// @param cur Cursor advanced past the block.
    /// @return data Decoded byte payload.
    function unpackBytes(Cur memory cur) internal pure returns (bytes calldata data) {
        uint end;
        (data, end) = Blocks.unpackBytes(cur.state.absolute());
        cur.state = cur.state.seekAbs(end);
    }

    /// @notice Decode and consume one STRING block.
    /// @param cur Cursor advanced past the block.
    /// @return data Decoded string payload.
    function unpackString(Cur memory cur) internal pure returns (string memory data) {
        bytes calldata value;
        uint end;
        (value, end) = Blocks.unpackString(cur.state.absolute());
        cur.state = cur.state.seekAbs(end);
        data = string(value);
    }

    // -------------------------------------------------------------------------
    // Execution-compatible fixed-width block decoding
    // -------------------------------------------------------------------------

    /// @dev Return the next raw calldata word and advance by `size` bytes.
    function next(Cur memory cur, uint size) private pure returns (bytes32 value) {
        value = Blocks.read32(take(cur, size));
    }

    /// @notice Return the next raw byte and advance the cursor by one byte.
    function next1(Cur memory cur) internal pure returns (bytes1 value) {
        value = bytes1(next(cur, 1));
    }

    /// @notice Return the next two raw bytes and advance the cursor by two bytes.
    function next2(Cur memory cur) internal pure returns (bytes2 value) {
        value = bytes2(next(cur, 2));
    }

    /// @notice Return the next four raw bytes and advance the cursor by four bytes.
    function next4(Cur memory cur) internal pure returns (bytes4 value) {
        value = bytes4(next(cur, 4));
    }

    /// @notice Return the next eight raw bytes and advance the cursor by eight bytes.
    function next8(Cur memory cur) internal pure returns (bytes8 value) {
        value = bytes8(next(cur, 8));
    }

    /// @notice Return the next sixteen raw bytes and advance the cursor by sixteen bytes.
    function next16(Cur memory cur) internal pure returns (bytes16 value) {
        value = bytes16(next(cur, 16));
    }

    /// @notice Return the next raw calldata word and advance the cursor.
    /// @param cur Cursor advanced by one word.
    /// @return value Raw word at the cursor's previous position.
    function next32(Cur memory cur) internal pure returns (bytes32 value) {
        value = next(cur, Sizes.Word);
    }

    /// @notice Decode one fixed 32-byte payload described by `spec`.
    /// @param cur Cursor advanced past the block.
    /// @param spec Expected block specification.
    /// @return value Decoded payload word.
    function unpack32(Cur memory cur, uint spec) internal pure returns (bytes32 value) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.B32);
        if (Blocks.header(abs, Specs.key(spec)) != 32) revert Blocks.InvalidBlock();
        assembly ("memory-safe") {
            value := calldataload(add(abs, 0x08))
        }
    }

    /// @notice Decode and consume one ACCOUNT block.
    /// @param cur Cursor advanced past the block.
    /// @return account Decoded account identifier.
    function unpackAccount(Cur memory cur) internal pure returns (bytes32 account) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.B32);
        account = Blocks.unpackAccount(abs);
    }

    /// @notice Decode and consume one NODE block.
    /// @param cur Cursor advanced past the block.
    /// @return node Decoded node identifier.
    function unpackNode(Cur memory cur) internal pure returns (uint node) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.B32);
        node = Blocks.unpackNode(abs);
    }

    /// @notice Decode and consume one CASHOUT block.
    /// @param cur Cursor advanced past the block.
    /// @return amount Native-asset amount to withdraw.
    function unpackCashout(Cur memory cur) internal pure returns (uint amount) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.Cashout);
        amount = Blocks.unpackCashout(abs);
    }

    /// @notice Decode and consume one BOOTSTRAP block.
    /// @param cur Cursor advanced past the block.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded balance amount.
    /// @return budget Decoded native-value budget contribution.
    function unpackBootstrap(Cur memory cur) internal pure returns (bytes32 asset, uint amount, uint budget) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.Bootstrap);
        return Blocks.unpackBootstrap(abs);
    }

    /// @notice Decode and consume one ASSET block.
    /// @param cur Cursor advanced past the block.
    /// @return asset Decoded asset identifier.
    function unpackAsset(Cur memory cur) internal pure returns (bytes32 asset) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.B32);
        asset = Blocks.unpackAsset(abs);
    }

    /// @notice Decode and consume one ACCOUNT_ASSET block.
    /// @param cur Cursor advanced past the block.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    function unpackAccountAsset(Cur memory cur) internal pure returns (bytes32 account, bytes32 asset) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.B64);
        (account, asset) = Blocks.unpackAccountAsset(abs);
    }

    /// @notice Decode and consume one HOST_ASSET block.
    /// @param cur Cursor advanced past the block.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    function unpackHostAsset(Cur memory cur) internal pure returns (uint host, bytes32 asset) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.HostAsset);
        (host, asset) = Blocks.unpackHostAsset(abs);
    }

    /// @notice Decode and consume one AMOUNT block.
    /// @param cur Cursor advanced past the block.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
    function unpackAmount(Cur memory cur) internal pure returns (bytes32 asset, uint amount) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.Amount);
        (asset, amount) = Blocks.unpackAmount(abs);
    }

    /// @notice Decode and consume one BALANCE block.
    /// @param cur Cursor advanced past the block.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded balance.
    function unpackBalance(Cur memory cur) internal pure returns (bytes32 asset, uint amount) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.Balance);
        (asset, amount) = Blocks.unpackBalance(abs);
    }

    /// @notice Decode and consume one DEBT block.
    /// @param cur Cursor advanced past the block.
    /// @return liability Decoded liability identifier.
    /// @return debt Decoded debt quantity.
    function unpackDebt(Cur memory cur) internal pure returns (bytes32 liability, uint debt) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.Debt);
        (liability, debt) = Blocks.unpackDebt(abs);
    }

    /// @notice Decode one BALANCE block and associate it with `host`.
    /// @param cur Cursor advanced past the block.
    /// @param host Host identifier associated with the balance.
    /// @return value Structured host balance.
    function unpackBalanceForHost(Cur memory cur, uint host) internal pure returns (HostAmount memory value) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.Balance);
        value.host = host;
        (value.asset, value.amount) = Blocks.unpackBalance(abs);
    }

    /// @notice Decode and consume one ACCOUNT_AMOUNT block.
    /// @param cur Cursor advanced past the block.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded amount.
    function unpackAccountAmount(
        Cur memory cur
    ) internal pure returns (bytes32 account, bytes32 asset, uint amount) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.B96);
        (account, asset, amount) = Blocks.unpackAccountAmount(abs);
    }

    /// @notice Decode one ALLOCATION block into its structured value.
    /// @param cur Cursor advanced past the block.
    /// @return value Structured allocation.
    function unpackAllocationValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.B96);
        (value.host, value.asset, value.amount) = Blocks.unpackAllocation(abs);
    }

    /// @notice Decode and consume one ALLOWANCE block.
    /// @param cur Cursor advanced past the block.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded allowance.
    function unpackAllowance(Cur memory cur) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.B96);
        (host, asset, amount) = Blocks.unpackAllowance(abs);
    }

    /// @notice Decode and consume one TRANSACTION block.
    /// @param cur Cursor advanced past the block.
    /// @return from Decoded debit account.
    /// @return to Decoded credit account.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded transaction amount.
    function unpackTransaction(
        Cur memory cur
    ) internal pure returns (bytes32 from, bytes32 to, bytes32 asset, uint amount) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.Transaction);
        (from, to, asset, amount) = Blocks.unpackTransaction(abs);
    }

    // -------------------------------------------------------------------------
    // Execution-compatible dynamic block decoding
    // -------------------------------------------------------------------------

    /// @notice Decode and consume one CALL block.
    /// @param cur Cursor advanced past the block.
    /// @return target Decoded call target.
    /// @return resources Decoded packed resources.
    /// @return data Decoded call payload.
    function unpackCall(
        Cur memory cur
    ) internal pure returns (uint target, uint resources, bytes calldata data) {
        uint abs = cur.state.absolute();
        uint end;
        (target, resources, data, end) = Blocks.unpackCall(abs);
        cur.state = cur.state.seekAbs(end);
    }

    /// @notice Decode and consume one ANNOTATION block.
    /// @param cur Cursor advanced past the block.
    /// @return entity Decoded entity identifier.
    /// @return data Decoded annotation block stream.
    function unpackAnnotation(
        Cur memory cur
    ) internal pure returns (uint entity, bytes calldata data) {
        uint abs = cur.state.absolute();
        uint end;
        (entity, data, end) = Blocks.unpackAnnotation(abs);
        cur.state = cur.state.seekAbs(end);
    }

    /// @notice Decode and consume one CONTEXT block.
    /// @param cur Cursor advanced past the block.
    /// @return account Decoded account identifier.
    /// @return state Decoded state payload.
    /// @return input Decoded input payload.
    function unpackContext(
        Cur memory cur
    ) internal pure returns (bytes32 account, bytes calldata state, bytes calldata input) {
        uint abs = cur.state.absolute();
        uint end;
        (account, state, input, end) = Blocks.unpackContext(abs);
        cur.state = cur.state.seekAbs(end);
    }

    /// @notice Decode and consume one DISPATCH block.
    /// @param cur Cursor advanced past the block.
    /// @return portal Decoded destination portal.
    /// @return resources Decoded packed resources.
    /// @return payload Decoded dispatch payload.
    function unpackDispatch(
        Cur memory cur
    ) internal pure returns (uint portal, uint resources, bytes calldata payload) {
        uint abs = cur.state.absolute();
        uint end;
        (portal, resources, payload, end) = Blocks.unpackDispatch(abs);
        cur.state = cur.state.seekAbs(end);
    }

    /// @notice Decode and consume one LABEL block.
    /// @param cur Cursor advanced past the block.
    /// @return namespace Decoded label namespace.
    /// @return name Decoded label text.
    function unpackLabel(Cur memory cur) internal pure returns (bytes32 namespace, string memory name) {
        uint abs = cur.state.absolute();
        uint end;
        (namespace, name, end) = Blocks.unpackLabel(abs);
        cur.state = cur.state.seekAbs(end);
    }

    /// @notice Decode and consume one SCHEMA block.
    /// @param cur Cursor advanced past the block.
    /// @return spec Decoded block specification.
    /// @return body Decoded schema body.
    /// @return name Decoded schema name.
    function unpackSchema(Cur memory cur) internal pure returns (uint spec, string memory body, bytes32 name) {
        uint abs = cur.state.absolute();
        uint end;
        (spec, body, name, end) = Blocks.unpackSchema(abs);
        cur.state = cur.state.seekAbs(end);
    }

    /// @notice Decode and consume one RECOVER block.
    /// @param cur Cursor advanced past the block.
    /// @return handler Decoded recovery handler.
    /// @return resources Decoded packed resources.
    /// @return key Decoded recovery key.
    /// @return witness Decoded recovery witness.
    function unpackRecover(
        Cur memory cur
    ) internal pure returns (uint handler, uint resources, bytes32 key, bytes calldata witness) {
        uint abs = cur.state.absolute();
        uint end;
        (handler, resources, key, witness, end) = Blocks.unpackRecover(abs);
        cur.state = cur.state.seekAbs(end);
    }

    // -------------------------------------------------------------------------
    // Additional semantic block decoding
    // -------------------------------------------------------------------------

    /// @notice Decode one ACCOUNT_ASSET block into its structured value.
    /// @param cur Cursor advanced past the block.
    /// @return value Structured account and asset.
    function unpackAccountAssetValue(Cur memory cur) internal pure returns (AccountAsset memory value) {
        (value.account, value.asset) = unpackAccountAsset(cur);
    }

    /// @notice Decode one HOST_ASSET block into its structured value.
    /// @param cur Cursor advanced past the block.
    /// @return value Structured host and asset.
    function unpackHostAssetValue(Cur memory cur) internal pure returns (HostAsset memory value) {
        (value.host, value.asset) = unpackHostAsset(cur);
    }

    /// @notice Decode one AMOUNT block into its structured value.
    /// @param cur Cursor advanced past the block.
    /// @return value Structured asset amount.
    function unpackAmountValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        (value.asset, value.amount) = unpackAmount(cur);
    }

    /// @notice Decode one BALANCE block into its structured value.
    /// @param cur Cursor advanced past the block.
    /// @return value Structured asset balance.
    function unpackBalanceValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        (value.asset, value.amount) = unpackBalance(cur);
    }

    /// @notice Decode one DEBT block into its structured value.
    /// @param cur Cursor advanced past the block.
    /// @return value Structured liability and debt.
    function unpackDebtValue(Cur memory cur) internal pure returns (Debt memory value) {
        (value.liability, value.debt) = unpackDebt(cur);
    }

    /// @notice Decode and consume one HOST_ACCOUNT_ASSET block.
    /// @param cur Cursor advanced past the block.
    /// @return host Decoded host identifier.
    /// @return account Decoded account identifier.
    /// @return asset Decoded asset identifier.
    function unpackHostAccountAsset(
        Cur memory cur
    ) internal pure returns (uint host, bytes32 account, bytes32 asset) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.B96);
        (host, account, asset) = Blocks.unpackHostAccountAsset(abs);
    }

    /// @notice Decode one HOST_ACCOUNT_ASSET block into its structured value.
    /// @param cur Cursor advanced past the block.
    /// @return value Structured host, account, and asset.
    function unpackHostAccountAssetValue(Cur memory cur) internal pure returns (HostAccountAsset memory value) {
        (value.host, value.account, value.asset) = unpackHostAccountAsset(cur);
    }

    /// @notice Decode one ACCOUNT_AMOUNT block into its structured value.
    /// @param cur Cursor advanced past the block.
    /// @return value Structured account amount.
    function unpackAccountAmountValue(Cur memory cur) internal pure returns (AccountAmount memory value) {
        (value.account, value.asset, value.amount) = unpackAccountAmount(cur);
    }

    /// @notice Decode and consume one ALLOCATION block.
    /// @param cur Cursor advanced past the block.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded allocation.
    function unpackAllocation(Cur memory cur) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.B96);
        (host, asset, amount) = Blocks.unpackAllocation(abs);
    }

    /// @notice Decode one ALLOWANCE block into its structured value.
    /// @param cur Cursor advanced past the block.
    /// @return value Structured allowance.
    function unpackAllowanceValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        (value.host, value.asset, value.amount) = unpackAllowance(cur);
    }

    /// @notice Decode and consume one CUSTODY block.
    /// @param cur Cursor advanced past the block.
    /// @return host Decoded host identifier.
    /// @return asset Decoded asset identifier.
    /// @return amount Decoded custody amount.
    function unpackCustody(Cur memory cur) internal pure returns (uint host, bytes32 asset, uint amount) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.B96);
        (host, asset, amount) = Blocks.unpackCustody(abs);
    }

    /// @notice Decode one CUSTODY block into its structured value.
    /// @param cur Cursor advanced past the block.
    /// @return value Structured custody amount.
    function unpackCustodyValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        (value.host, value.asset, value.amount) = unpackCustody(cur);
    }

    /// @notice Decode and consume one POSITION block.
    function unpackPosition(
        Cur memory cur
    ) internal pure returns (bytes32 asset, uint amount, bytes32 liability, uint debt) {
        uint abs;
        (cur.state, abs) = cur.state.consume(Sizes.Position);
        (asset, amount, liability, debt) = Blocks.unpackPosition(abs);
    }

    /// @notice Decode one POSITION block into its structured value.
    function unpackPositionValue(Cur memory cur) internal pure returns (Position memory value) {
        (value.asset, value.amount, value.liability, value.debt) = unpackPosition(cur);
    }

    /// @notice Decode one TRANSACTION block into its structured value.
    /// @param cur Cursor advanced past the block.
    /// @return value Structured transaction.
    function unpackTransactionValue(Cur memory cur) internal pure returns (Tx memory value) {
        (value.from, value.to, value.asset, value.amount) = unpackTransaction(cur);
    }

    /// @notice Decode and consume one STEP block.
    /// @param cur Cursor advanced past the block.
    /// @return cmd Decoded command identifier.
    /// @return value Decoded native value.
    /// @return input Decoded command input.
    function unpackStep(
        Cur memory cur
    ) internal pure returns (uint cmd, uint value, bytes calldata input) {
        uint abs = cur.state.absolute();
        uint end;
        (cmd, value, input, end) = Blocks.unpackStep(abs);
        cur.state = cur.state.seekAbs(end);
    }

    /// @notice Decode and consume one RELAY block.
    /// @param cur Cursor advanced past the block.
    /// @return portal Decoded destination portal.
    /// @return resources Decoded packed resources.
    /// @return input Decoded relay input.
    function unpackRelay(
        Cur memory cur
    ) internal pure returns (uint portal, uint resources, bytes calldata input) {
        uint abs = cur.state.absolute();
        uint end;
        (portal, resources, input, end) = Blocks.unpackRelay(abs);
        cur.state = cur.state.seekAbs(end);
    }

}
