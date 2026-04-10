// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {HostAsset, AssetAmount, HostAmount, Tx, Keys, Sizes} from "./Schema.sol";
import {ALLOC_SCALE, Writer, Writers} from "./Writers.sol";

struct Cur {
    uint offset;
    uint i;
    uint len;
    uint bound;
}

using Cursors for Cur;

library Cursors {
    error MalformedBlocks();
    error InvalidBlock();
    error ZeroCursor();
    error ZeroGroup();
    error ZeroRecipient();
    error ZeroNode();
    error UnexpectedValue();
    error BadRatio();

    function open(bytes calldata source) internal pure returns (Cur memory cur) {
        uint offset;
        assembly ("memory-safe") {
            offset := source.offset
        }
        cur.offset = offset;
        cur.len = source.length;
    }

    function seek(Cur memory cur, uint i) internal pure returns (Cur memory) {
        if (i > cur.len) revert MalformedBlocks();
        cur.i = i;
        return cur;
    }

    function peek(Cur memory cur, uint i) internal pure returns (bytes4 key, uint len) {
        if (i + 8 > cur.len) revert MalformedBlocks();
        uint abs = cur.offset + i;
        key = bytes4(msg.data[abs:abs + 4]);
        len = uint32(bytes4(msg.data[abs + 4:abs + 8]));
        if (i + 8 + len > cur.len) revert MalformedBlocks();
    }

    function expect(
        Cur memory cur,
        uint i,
        bytes4 key,
        uint min,
        uint max
    ) internal pure returns (uint abs, uint next) {
        (bytes4 current, uint len) = peek(cur, i);
        if (current != key) revert InvalidBlock();
        abs = cur.offset + i + 8;
        next = i + 8 + len;
        if (len < min || (max != 0 && len > max)) revert InvalidBlock();
    }

    function countRun(Cur memory cur, uint i, bytes4 key) internal pure returns (uint total, uint next) {
        next = i;
        while (next < cur.len) {
            (bytes4 current, uint len) = peek(cur, next);
            if (current != key) break;
            next += 8 + len;

            unchecked {
                ++total;
            }
        }
    }

    function primeRun(Cur memory cur, uint group) internal pure returns (bytes4 key, uint count) {
        if (group == 0) revert ZeroGroup();
        key = cur.len < 4 ? bytes4(0) : bytes4(msg.data[cur.offset:cur.offset + 4]);
        (count, cur.bound) = countRun(cur, cur.i, key);
        if (count % group != 0) revert BadRatio();
    }

    function find(Cur memory cur, uint i, bytes4 key) internal pure returns (uint) {
        while (i < cur.len) {
            (bytes4 current, uint len) = peek(cur, i);
            if (current == key) return i;
            i += 8 + len;
        }
        return cur.len;
    }

    function find(Cur memory cur, bytes4 key) internal pure returns (uint) {
        return find(cur, cur.i, key);
    }

    function consume(Cur memory cur, bytes4 key, uint min, uint max) internal pure returns (uint abs) {
        uint next;
        (abs, next) = expect(cur, cur.i, key, min, max);
        cur.i = next;
    }

    function bundle(Cur memory cur) internal pure returns (Cur memory out) {
        (uint abs, uint next) = expect(cur, cur.i, Keys.Bundle, 0, 0);
        uint len = next - (abs - cur.offset);
        out.offset = abs;
        out.len = len;
        cur.i = next;
    }

    function complete(Cur memory cur) internal pure {
        if (cur.bound == 0 || cur.i < cur.bound) revert ZeroCursor();
    }

    function complete(Cur memory cur, Writer memory writer) internal pure returns (bytes memory) {
        if (cur.bound == 0 || cur.i < cur.bound) revert ZeroCursor();
        return Writers.finish(writer);
    }

    function create32(bytes4 key, bytes32 value) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x20)), bytes4(uint32(0x20)), value);
    }

    function create64(bytes4 key, bytes32 a, bytes32 b) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x40)), bytes4(uint32(0x40)), a, b);
    }

    function create96(bytes4 key, bytes32 a, bytes32 b, bytes32 c) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x60)), bytes4(uint32(0x60)), a, b, c);
    }

    function create128(bytes4 key, bytes32 a, bytes32 b, bytes32 c, bytes32 d) internal pure returns (bytes memory) {
        return bytes.concat(key, bytes4(uint32(0x80)), bytes4(uint32(0x80)), a, b, c, d);
    }

    function toBountyBlock(uint bounty, bytes32 relayer) internal pure returns (bytes memory) {
        return create64(Keys.Bounty, bytes32(bounty), relayer);
    }

    function toBalanceBlock(bytes32 asset, bytes32 meta, uint amount) internal pure returns (bytes memory) {
        return create96(Keys.Balance, asset, meta, bytes32(amount));
    }

    function toCustodyBlock(uint host, bytes32 asset, bytes32 meta, uint amount) internal pure returns (bytes memory) {
        return create128(Keys.Custody, bytes32(host), asset, meta, bytes32(amount));
    }

    function nodeAfter(Cur memory cur, uint backup) internal pure returns (uint node) {
        uint i = find(cur, cur.bound, Keys.Node);
        if (i == cur.len) return backup;

        (uint abs, ) = expect(cur, i, Keys.Node, 32, 32);
        return uint(bytes32(msg.data[abs:abs + 32]));
    }

    function recipientAfter(Cur memory cur, bytes32 backup) internal pure returns (bytes32 account) {
        uint i = find(cur, cur.bound, Keys.Recipient);
        if (i == cur.len) return backup;

        (uint abs, ) = expect(cur, i, Keys.Recipient, 32, 32);
        return bytes32(msg.data[abs:abs + 32]);
    }

    function authLast(
        Cur memory cur,
        uint cid
    ) internal pure returns (bytes32 hash, uint deadline, bytes calldata proof) {
        if (cur.len - cur.i < Sizes.Auth) revert MalformedBlocks();

        uint i = cur.len - Sizes.Auth;
        if (i < cur.bound) revert MalformedBlocks();

        (deadline, proof) = expectAuth(cur, i, cid);
        hash = keccak256(msg.data[cur.offset + cur.i:cur.offset + cur.len - Sizes.Proof]);
    }

    function unpackBalanceValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        uint abs = consume(cur, Keys.Balance, 96, 96);
        value.asset = bytes32(msg.data[abs:abs + 32]);
        value.meta = bytes32(msg.data[abs + 32:abs + 64]);
        value.amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function unpackAmountValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        uint abs = consume(cur, Keys.Amount, 96, 96);
        value.asset = bytes32(msg.data[abs:abs + 32]);
        value.meta = bytes32(msg.data[abs + 32:abs + 64]);
        value.amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function unpackAmount(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, Keys.Amount, 96, 96);
        asset = bytes32(msg.data[abs:abs + 32]);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function unpackBalance(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, Keys.Balance, 96, 96);
        asset = bytes32(msg.data[abs:abs + 32]);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function unpackMinimum(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, Keys.Minimum, 96, 96);
        asset = bytes32(msg.data[abs:abs + 32]);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function unpackMinimumValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        uint abs = consume(cur, Keys.Minimum, 96, 96);
        value.asset = bytes32(msg.data[abs:abs + 32]);
        value.meta = bytes32(msg.data[abs + 32:abs + 64]);
        value.amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function unpackMaximum(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        uint abs = consume(cur, Keys.Maximum, 96, 96);
        asset = bytes32(msg.data[abs:abs + 32]);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function unpackMaximumValue(Cur memory cur) internal pure returns (AssetAmount memory value) {
        uint abs = consume(cur, Keys.Maximum, 96, 96);
        value.asset = bytes32(msg.data[abs:abs + 32]);
        value.meta = bytes32(msg.data[abs + 32:abs + 64]);
        value.amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function unpackStep(Cur memory cur) internal pure returns (uint target, uint value, bytes calldata req) {
        uint abs = consume(cur, Keys.Step, 64, 0);
        target = uint(bytes32(msg.data[abs:abs + 32]));
        value = uint(bytes32(msg.data[abs + 32:abs + 64]));
        req = msg.data[abs + 64:cur.offset + cur.i];
    }

    function unpackRecipient(Cur memory cur) internal pure returns (bytes32 account) {
        uint abs = consume(cur, Keys.Recipient, 32, 32);
        account = bytes32(msg.data[abs:abs + 32]);
    }

    function unpackParty(Cur memory cur) internal pure returns (bytes32 account) {
        uint abs = consume(cur, Keys.Party, 32, 32);
        account = bytes32(msg.data[abs:abs + 32]);
    }

    function unpackRate(Cur memory cur) internal pure returns (uint value) {
        uint abs = consume(cur, Keys.Rate, 32, 32);
        value = uint(bytes32(msg.data[abs:abs + 32]));
    }

    function unpackQuantity(Cur memory cur) internal pure returns (uint amount) {
        uint abs = consume(cur, Keys.Quantity, 32, 32);
        amount = uint(bytes32(msg.data[abs:abs + 32]));
    }

    function unpackAsset(Cur memory cur) internal pure returns (bytes32 asset, bytes32 meta) {
        uint abs = consume(cur, Keys.Asset, 64, 64);
        asset = bytes32(msg.data[abs:abs + 32]);
        meta = bytes32(msg.data[abs + 32:abs + 64]);
    }

    function unpackFunding(Cur memory cur) internal pure returns (uint host, uint amount) {
        uint abs = consume(cur, Keys.Funding, 64, 64);
        host = uint(bytes32(msg.data[abs:abs + 32]));
        amount = uint(bytes32(msg.data[abs + 32:abs + 64]));
    }

    function unpackBounty(Cur memory cur) internal pure returns (uint amount, bytes32 relayer) {
        uint abs = consume(cur, Keys.Bounty, 64, 64);
        amount = uint(bytes32(msg.data[abs:abs + 32]));
        relayer = bytes32(msg.data[abs + 32:abs + 64]);
    }

    function unpackListing(Cur memory cur) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        uint abs = consume(cur, Keys.Listing, 96, 96);
        host = uint(bytes32(msg.data[abs:abs + 32]));
        asset = bytes32(msg.data[abs + 32:abs + 64]);
        meta = bytes32(msg.data[abs + 64:abs + 96]);
    }

    function unpackListingValue(Cur memory cur) internal pure returns (HostAsset memory value) {
        uint abs = consume(cur, Keys.Listing, 96, 96);
        value.host = uint(bytes32(msg.data[abs:abs + 32]));
        value.asset = bytes32(msg.data[abs + 32:abs + 64]);
        value.meta = bytes32(msg.data[abs + 64:abs + 96]);
    }

    function unpackNode(Cur memory cur) internal pure returns (uint node) {
        uint abs = consume(cur, Keys.Node, 32, 32);
        node = uint(bytes32(msg.data[abs:abs + 32]));
    }

    function unpackRoute(Cur memory cur) internal pure returns (bytes calldata data) {
        (uint abs, uint next) = expect(cur, cur.i, Keys.Route, 0, 0);
        data = msg.data[abs:cur.offset + next];
        cur.i = next;
    }

    function unpackRouteUint(Cur memory cur) internal pure returns (uint value) {
        uint abs = consume(cur, Keys.Route, 32, 32);
        value = uint(bytes32(msg.data[abs:abs + 32]));
    }

    function unpackRoute2Uint(Cur memory cur) internal pure returns (uint a, uint b) {
        uint abs = consume(cur, Keys.Route, 64, 64);
        a = uint(bytes32(msg.data[abs:abs + 32]));
        b = uint(bytes32(msg.data[abs + 32:abs + 64]));
    }

    function unpackRoute3Uint(Cur memory cur) internal pure returns (uint a, uint b, uint c) {
        uint abs = consume(cur, Keys.Route, 96, 96);
        a = uint(bytes32(msg.data[abs:abs + 32]));
        b = uint(bytes32(msg.data[abs + 32:abs + 64]));
        c = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function unpackRoute32(Cur memory cur) internal pure returns (bytes32 value) {
        uint abs = consume(cur, Keys.Route, 32, 32);
        value = bytes32(msg.data[abs:abs + 32]);
    }

    function unpackRoute64(Cur memory cur) internal pure returns (bytes32 a, bytes32 b) {
        uint abs = consume(cur, Keys.Route, 64, 64);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
    }

    function unpackRoute96(Cur memory cur) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        uint abs = consume(cur, Keys.Route, 96, 96);
        a = bytes32(msg.data[abs:abs + 32]);
        b = bytes32(msg.data[abs + 32:abs + 64]);
        c = bytes32(msg.data[abs + 64:abs + 96]);
    }

    function unpackCustodyValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        uint abs = consume(cur, Keys.Custody, 128, 128);
        value.host = uint(bytes32(msg.data[abs:abs + 32]));
        value.asset = bytes32(msg.data[abs + 32:abs + 64]);
        value.meta = bytes32(msg.data[abs + 64:abs + 96]);
        value.amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    function unpackAllocationValue(Cur memory cur) internal pure returns (HostAmount memory value) {
        uint abs = consume(cur, Keys.Allocation, 128, 128);
        value.host = uint(bytes32(msg.data[abs:abs + 32]));
        value.asset = bytes32(msg.data[abs + 32:abs + 64]);
        value.meta = bytes32(msg.data[abs + 64:abs + 96]);
        value.amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    function unpackTxValue(Cur memory cur) internal pure returns (Tx memory value) {
        uint abs = consume(cur, Keys.Transaction, 160, 160);
        value.from = bytes32(msg.data[abs:abs + 32]);
        value.to = bytes32(msg.data[abs + 32:abs + 64]);
        value.asset = bytes32(msg.data[abs + 64:abs + 96]);
        value.meta = bytes32(msg.data[abs + 96:abs + 128]);
        value.amount = uint(bytes32(msg.data[abs + 128:abs + 160]));
    }

    function expectAuth(Cur memory cur, uint i, uint cid) internal pure returns (uint deadline, bytes calldata proof) {
        (uint abs, uint next) = expect(cur, i, Keys.Auth, 149, 0);
        if (uint(bytes32(msg.data[abs:abs + 32])) != cid) revert UnexpectedValue();
        deadline = uint(bytes32(msg.data[abs + 32:abs + 64]));
        proof = msg.data[abs + 64:cur.offset + next];
    }

    function expectAmount(Cur memory cur, uint i, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        (uint abs, ) = expect(cur, i, Keys.Amount, 96, 96);
        if (bytes32(msg.data[abs:abs + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[abs + 32:abs + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function expectBalance(Cur memory cur, uint i, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        (uint abs, ) = expect(cur, i, Keys.Balance, 96, 96);
        if (bytes32(msg.data[abs:abs + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[abs + 32:abs + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function expectMinimum(Cur memory cur, uint i, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        (uint abs, ) = expect(cur, i, Keys.Minimum, 96, 96);
        if (bytes32(msg.data[abs:abs + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[abs + 32:abs + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function expectMaximum(Cur memory cur, uint i, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        (uint abs, ) = expect(cur, i, Keys.Maximum, 96, 96);
        if (bytes32(msg.data[abs:abs + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[abs + 32:abs + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[abs + 64:abs + 96]));
    }

    function expectCustody(Cur memory cur, uint i, uint host) internal pure returns (AssetAmount memory value) {
        (uint abs, ) = expect(cur, i, Keys.Custody, 128, 128);
        if (uint(bytes32(msg.data[abs:abs + 32])) != host) revert UnexpectedValue();
        value.asset = bytes32(msg.data[abs + 32:abs + 64]);
        value.meta = bytes32(msg.data[abs + 64:abs + 96]);
        value.amount = uint(bytes32(msg.data[abs + 96:abs + 128]));
    }

    function requireAuth(Cur memory cur, uint cid) internal pure returns (uint deadline, bytes calldata proof) {
        (deadline, proof) = expectAuth(cur, cur.i, cid);
        cur.i += 64 + proof.length;
    }

    function requireAmount(Cur memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        amount = expectAmount(cur, cur.i, asset, meta);
        cur.i += 104;
    }

    function requireBalance(Cur memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        amount = expectBalance(cur, cur.i, asset, meta);
        cur.i += 104;
    }

    function requireMinimum(Cur memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        amount = expectMinimum(cur, cur.i, asset, meta);
        cur.i += 104;
    }

    function requireMaximum(Cur memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        amount = expectMaximum(cur, cur.i, asset, meta);
        cur.i += 104;
    }

    function requireCustody(Cur memory cur, uint host) internal pure returns (AssetAmount memory value) {
        value = expectCustody(cur, cur.i, host);
        cur.i += 136;
    }

}
