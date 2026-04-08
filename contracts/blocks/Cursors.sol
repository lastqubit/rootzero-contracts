// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.33;

import {AUTH_PROOF_LEN, AUTH_TOTAL_LEN, HostAsset, AssetAmount, HostAmount, Tx, Keys} from "./Schema.sol";
import {BALANCE_BLOCK_LEN, BOUNTY_BLOCK_LEN, CUSTODY_BLOCK_LEN, TX_BLOCK_LEN, Writer, Writers} from "./Writers.sol";

struct Cursor {
    uint start;
    uint i;
    uint end;
    uint next;
}

using Cursors for Cursor;

library Cursors {
    error MalformedBlocks();
    error InvalidBlock();
    error ZeroCursor();
    error ZeroRecipient();
    error ZeroNode();
    error UnexpectedValue();

    // ── infrastructure ────────────────────────────────────────────────────────

    function openAt(uint base, uint i, uint eod) private pure returns (Cursor memory cur) {
        if (i == eod) return Cursor(base + i, base + i, base + i, i);
        uint start = i + 8;
        if (start > eod) revert MalformedBlocks();

        uint abs = base + i;
        bool bundle = bytes4(msg.data[abs:abs + 4]) == Keys.Bundle;
        uint end = start + uint32(bytes4(msg.data[abs + 4:abs + 8]));
        if (end > eod) revert MalformedBlocks();

        cur.start = bundle ? base + start : abs;
        cur.i = cur.start;
        cur.end = base + end;
        cur.next = end;
    }

    function openAt(uint i) internal pure returns (Cursor memory cur) {
        return openAt(0, i, msg.data.length);
    }

    function openBlock(bytes calldata source, uint i) internal pure returns (Cursor memory cur) {
        uint base;
        assembly ("memory-safe") {
            base := source.offset
        }
        return openAt(base, i, source.length);
    }

    function openCount(bytes calldata source, uint i, uint n) internal pure returns (Cursor memory cur) {
        if (n == 0) revert ZeroCursor();

        uint base;
        assembly ("memory-safe") {
            base := source.offset
        }

        uint next = i;
        for (uint j; j < n; ) {
            next = openAt(base, next, source.length).next;
            unchecked {
                ++j;
            }
        }

        cur.start = base + i;
        cur.i = cur.start;
        cur.end = base + next;
        cur.next = next;
    }

    function openRun(bytes calldata source, uint i, bytes4 key) internal pure returns (Cursor memory cur, uint total) {
        uint next;
        (total, next) = count(source, i, key);
        uint base;
        assembly ("memory-safe") {
            base := source.offset
        }
        cur.start = base + i;
        cur.i = cur.start;
        cur.end = base + next;
        cur.next = next;
    }

    function openRun(
        bytes calldata source,
        uint i,
        bytes4 key,
        uint divisor
    ) internal pure returns (Cursor memory cur) {
        uint total;
        (cur, total) = openRun(source, i, key);
        if (divisor == 0 || total == 0) revert ZeroCursor();
        if (total % divisor != 0) revert MalformedBlocks();
    }

    function openInput(bytes calldata source, uint i) internal pure returns (Cursor memory cur, uint total) {
        if (i == source.length) return (openStream(source, i), 0);
        return openRun(source, i, bytes4(source[i:i + 4]));
    }

    function openInput(bytes calldata source, uint i, uint divisor) internal pure returns (Cursor memory cur) {
        uint total;
        (cur, total) = openInput(source, i);
        if (divisor == 0 || total == 0) revert ZeroCursor();
        if (total % divisor != 0) revert MalformedBlocks();
    }

    function openStream(bytes calldata source, uint i) internal pure returns (Cursor memory cur) {
        uint base;
        uint end = source.length;
        assembly ("memory-safe") {
            base := source.offset
        }
        if (i > end) revert MalformedBlocks();
        cur.start = base + i;
        cur.i = cur.start;
        cur.end = base + end;
        cur.next = end;
    }

    function isAt(Cursor memory cur, bytes4 key) internal pure returns (bool) {
        if (cur.i + 4 > cur.end) return false;
        return bytes4(msg.data[cur.i:cur.i + 4]) == key;
    }

    function find(Cursor memory cur, bytes4 key) internal pure returns (Cursor memory out) {
        uint i = cur.i;
        while (i < cur.end) {
            out = openAt(i);
            if (out.end > cur.end) revert MalformedBlocks();
            if (bytes4(msg.data[i:i + 4]) == key) return out;
            i = out.next;
        }

        uint base = cur.end - cur.next;
        return Cursor(cur.end, cur.end, cur.end, cur.end - base);
    }

    function findFrom(bytes calldata source, uint i, uint limit, bytes4 key) internal pure returns (Cursor memory out) {
        uint base;
        assembly ("memory-safe") {
            base := source.offset
        }
        if (limit > source.length) revert MalformedBlocks();
        while (i < limit) {
            out = openAt(base, i, source.length);
            if (out.next > limit) revert MalformedBlocks();
            if (bytes4(source[i:i + 4]) == key) return out;
            i = out.next;
        }

        uint end = base + limit;
        return Cursor(end, end, end, limit);
    }

    function count(bytes calldata source, uint i, bytes4 key) internal pure returns (uint total, uint next) {
        uint base;
        assembly ("memory-safe") {
            base := source.offset
        }
        next = i;
        while (next < source.length) {
            Cursor memory cur = openAt(base, next, source.length);
            if (bytes4(source[next:next + 4]) != key) break;
            unchecked {
                ++total;
            }
            next = cur.next;
        }
    }

    function count(bytes calldata source, uint i) internal pure returns (uint total, uint next) {
        uint base;
        assembly ("memory-safe") {
            base := source.offset
        }
        next = i;
        while (next < source.length) {
            next = openAt(base, next, source.length).next;
            unchecked {
                ++total;
            }
        }
    }

    function take(Cursor memory cur) internal pure returns (Cursor memory out) {
        out = openAt(cur.i);
        if (out.end > cur.end) revert MalformedBlocks();

        uint base = cur.end - cur.next;
        out.next = out.end - base;

        cur.i = out.end;
    }

    function drain(Cursor memory cur) internal pure returns (Cursor memory) {
        if (cur.i == cur.start) revert ZeroCursor();
        cur.i = cur.end;
        return cur;
    }

    function finish(Cursor memory cur) internal pure {
        if (cur.i == cur.start || cur.i != cur.end) revert ZeroCursor();
    }

    function finish(Cursor memory a, Cursor memory b) internal pure {
        if (a.i == a.start || a.i != a.end || b.i == b.start || b.i != b.end) revert ZeroCursor();
    }

    function complete(Cursor memory cur) internal pure returns (bytes memory) {
        cur.finish();
        return "";
    }

    function complete(Cursor memory a, Cursor memory b) internal pure returns (bytes memory) {
        a.finish();
        b.finish();
        return "";
    }

    function expect(Cursor memory cur, bytes4 key, uint min, uint max) internal pure returns (uint i, uint end) {
        if (cur.i + 8 > cur.end) revert MalformedBlocks();
        if (bytes4(msg.data[cur.i:cur.i + 4]) != key) revert InvalidBlock();

        i = cur.i + 8;
        end = i + uint32(bytes4(msg.data[cur.i + 4:i]));
        if (end > cur.end) revert MalformedBlocks();
        uint len = end - i;
        if (len < min || (max != 0 && len > max)) revert InvalidBlock();
        cur.i = end;
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

    function maybeNodeAfter(Cursor memory cur, bytes calldata source) internal pure returns (uint id) {
        Cursor memory node = findFrom(source, cur.next, source.length, Keys.Node);
        if (node.i == node.end) return 0;
        return node.unpackNode();
    }

    function resolveRecipient(
        bytes calldata source,
        uint i,
        uint limit,
        bytes32 backup
    ) internal pure returns (bytes32) {
        Cursor memory ref = findFrom(source, i, limit, Keys.Recipient);
        bytes32 to = ref.i < ref.end ? ref.unpackRecipient() : backup;
        if (to == 0) revert ZeroRecipient();
        return to;
    }

    function resolveNode(bytes calldata source, uint i, uint limit, uint backup) internal pure returns (uint) {
        Cursor memory ref = findFrom(source, i, limit, Keys.Node);
        uint node = ref.i < ref.end ? ref.unpackNode() : backup;
        if (node == 0) revert ZeroNode();
        return node;
    }

    function resolveAuth(
        Cursor memory input,
        uint expectedCid
    ) internal pure returns (bytes32 hash, uint deadline, bytes calldata proof) {
        if (input.end - input.i < AUTH_TOTAL_LEN) revert MalformedBlocks();

        uint authStart = input.end - AUTH_TOTAL_LEN;
        Cursor memory auth = openAt(authStart);
        if (auth.end != input.end) revert MalformedBlocks();

        (deadline, proof) = auth.expectAuth(expectedCid);

        hash = keccak256(msg.data[input.i:input.end - AUTH_PROOF_LEN]);
    }

    // cursor unpack*

    function unpackRoute(Cursor memory cur) internal pure returns (bytes calldata data) {
        (uint i, uint end) = expect(cur, Keys.Route, 0, 0);
        data = msg.data[i:end];
        cur.i = end;
    }

    function unpackRouteUint(Cursor memory cur) internal pure returns (uint value) {
        (uint i, uint end) = expect(cur, Keys.Route, 32, 32);
        value = uint(bytes32(msg.data[i:i + 32]));
        cur.i = end;
    }

    function unpackRoute2Uint(Cursor memory cur) internal pure returns (uint a, uint b) {
        (uint i, uint end) = expect(cur, Keys.Route, 64, 64);
        a = uint(bytes32(msg.data[i:i + 32]));
        b = uint(bytes32(msg.data[i + 32:i + 64]));
        cur.i = end;
    }

    function unpackRoute3Uint(Cursor memory cur) internal pure returns (uint a, uint b, uint c) {
        (uint i, uint end) = expect(cur, Keys.Route, 96, 96);
        a = uint(bytes32(msg.data[i:i + 32]));
        b = uint(bytes32(msg.data[i + 32:i + 64]));
        c = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function unpackRoute32(Cursor memory cur) internal pure returns (bytes32 value) {
        (uint i, uint end) = expect(cur, Keys.Route, 32, 32);
        value = bytes32(msg.data[i:i + 32]);
        cur.i = end;
    }

    function unpackRoute64(Cursor memory cur) internal pure returns (bytes32 a, bytes32 b) {
        (uint i, uint end) = expect(cur, Keys.Route, 64, 64);
        a = bytes32(msg.data[i:i + 32]);
        b = bytes32(msg.data[i + 32:i + 64]);
        cur.i = end;
    }

    function unpackRoute96(Cursor memory cur) internal pure returns (bytes32 a, bytes32 b, bytes32 c) {
        (uint i, uint end) = expect(cur, Keys.Route, 96, 96);
        a = bytes32(msg.data[i:i + 32]);
        b = bytes32(msg.data[i + 32:i + 64]);
        c = bytes32(msg.data[i + 64:i + 96]);
        cur.i = end;
    }

    function unpackNode(Cursor memory cur) internal pure returns (uint id) {
        (uint i, uint end) = expect(cur, Keys.Node, 32, 32);
        id = uint(bytes32(msg.data[i:i + 32]));
        cur.i = end;
    }

    function unpackRecipient(Cursor memory cur) internal pure returns (bytes32 account) {
        (uint i, uint end) = expect(cur, Keys.Recipient, 32, 32);
        account = bytes32(msg.data[i:i + 32]);
        cur.i = end;
    }

    function unpackParty(Cursor memory cur) internal pure returns (bytes32 account) {
        (uint i, uint end) = expect(cur, Keys.Party, 32, 32);
        account = bytes32(msg.data[i:i + 32]);
        cur.i = end;
    }

    function unpackRate(Cursor memory cur) internal pure returns (uint value) {
        (uint i, uint end) = expect(cur, Keys.Rate, 32, 32);
        value = uint(bytes32(msg.data[i:i + 32]));
        cur.i = end;
    }

    function unpackQuantity(Cursor memory cur) internal pure returns (uint amount) {
        (uint i, uint end) = expect(cur, Keys.Quantity, 32, 32);
        amount = uint(bytes32(msg.data[i:i + 32]));
        cur.i = end;
    }

    function unpackAsset(Cursor memory cur) internal pure returns (bytes32 asset, bytes32 meta) {
        (uint i, uint end) = expect(cur, Keys.Asset, 64, 64);
        asset = bytes32(msg.data[i:i + 32]);
        meta = bytes32(msg.data[i + 32:i + 64]);
        cur.i = end;
    }

    function unpackFunding(Cursor memory cur) internal pure returns (uint host, uint amount) {
        (uint i, uint end) = expect(cur, Keys.Funding, 64, 64);
        host = uint(bytes32(msg.data[i:i + 32]));
        amount = uint(bytes32(msg.data[i + 32:i + 64]));
        cur.i = end;
    }

    function unpackBounty(Cursor memory cur) internal pure returns (uint amount, bytes32 relayer) {
        (uint i, uint end) = expect(cur, Keys.Bounty, 64, 64);
        amount = uint(bytes32(msg.data[i:i + 32]));
        relayer = bytes32(msg.data[i + 32:i + 64]);
        cur.i = end;
    }

    function unpackAmount(Cursor memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        (uint i, uint end) = expect(cur, Keys.Amount, 96, 96);
        asset = bytes32(msg.data[i:i + 32]);
        meta = bytes32(msg.data[i + 32:i + 64]);
        amount = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function unpackBalance(Cursor memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        (uint i, uint end) = expect(cur, Keys.Balance, 96, 96);
        asset = bytes32(msg.data[i:i + 32]);
        meta = bytes32(msg.data[i + 32:i + 64]);
        amount = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function unpackMinimum(Cursor memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        (uint i, uint end) = expect(cur, Keys.Minimum, 96, 96);
        asset = bytes32(msg.data[i:i + 32]);
        meta = bytes32(msg.data[i + 32:i + 64]);
        amount = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function unpackMaximum(Cursor memory cur) internal pure returns (bytes32 asset, bytes32 meta, uint amount) {
        (uint i, uint end) = expect(cur, Keys.Maximum, 96, 96);
        asset = bytes32(msg.data[i:i + 32]);
        meta = bytes32(msg.data[i + 32:i + 64]);
        amount = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function unpackListing(Cursor memory cur) internal pure returns (uint host, bytes32 asset, bytes32 meta) {
        (uint i, uint end) = expect(cur, Keys.Listing, 96, 96);
        host = uint(bytes32(msg.data[i:i + 32]));
        asset = bytes32(msg.data[i + 32:i + 64]);
        meta = bytes32(msg.data[i + 64:i + 96]);
        cur.i = end;
    }

    function unpackStep(Cursor memory cur) internal pure returns (uint target, uint value, bytes calldata req) {
        (uint i, uint end) = expect(cur, Keys.Step, 64, 0);
        target = uint(bytes32(msg.data[i:i + 32]));
        value = uint(bytes32(msg.data[i + 32:i + 64]));
        req = msg.data[i + 64:end];
        cur.i = end;
    }

    // cursor unpack*Value

    function unpackAmountValue(Cursor memory cur) internal pure returns (AssetAmount memory value) {
        (uint i, uint end) = expect(cur, Keys.Amount, 96, 96);
        value.asset = bytes32(msg.data[i:i + 32]);
        value.meta = bytes32(msg.data[i + 32:i + 64]);
        value.amount = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function unpackBalanceValue(Cursor memory cur) internal pure returns (AssetAmount memory value) {
        (uint i, uint end) = expect(cur, Keys.Balance, 96, 96);
        value.asset = bytes32(msg.data[i:i + 32]);
        value.meta = bytes32(msg.data[i + 32:i + 64]);
        value.amount = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function unpackMinimumValue(Cursor memory cur) internal pure returns (AssetAmount memory value) {
        (uint i, uint end) = expect(cur, Keys.Minimum, 96, 96);
        value.asset = bytes32(msg.data[i:i + 32]);
        value.meta = bytes32(msg.data[i + 32:i + 64]);
        value.amount = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function unpackMaximumValue(Cursor memory cur) internal pure returns (AssetAmount memory value) {
        (uint i, uint end) = expect(cur, Keys.Maximum, 96, 96);
        value.asset = bytes32(msg.data[i:i + 32]);
        value.meta = bytes32(msg.data[i + 32:i + 64]);
        value.amount = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function unpackListingValue(Cursor memory cur) internal pure returns (HostAsset memory value) {
        (uint i, uint end) = expect(cur, Keys.Listing, 96, 96);
        value.host = uint(bytes32(msg.data[i:i + 32]));
        value.asset = bytes32(msg.data[i + 32:i + 64]);
        value.meta = bytes32(msg.data[i + 64:i + 96]);
        cur.i = end;
    }

    function unpackCustodyValue(Cursor memory cur) internal pure returns (HostAmount memory value) {
        (uint i, uint end) = expect(cur, Keys.Custody, 128, 128);
        value.host = uint(bytes32(msg.data[i:i + 32]));
        value.asset = bytes32(msg.data[i + 32:i + 64]);
        value.meta = bytes32(msg.data[i + 64:i + 96]);
        value.amount = uint(bytes32(msg.data[i + 96:i + 128]));
        cur.i = end;
    }

    function unpackAllocationValue(Cursor memory cur) internal pure returns (HostAmount memory value) {
        (uint i, uint end) = expect(cur, Keys.Allocation, 128, 128);
        value.host = uint(bytes32(msg.data[i:i + 32]));
        value.asset = bytes32(msg.data[i + 32:i + 64]);
        value.meta = bytes32(msg.data[i + 64:i + 96]);
        value.amount = uint(bytes32(msg.data[i + 96:i + 128]));
        cur.i = end;
    }

    function unpackTxValue(Cursor memory cur) internal pure returns (Tx memory value) {
        (uint i, uint end) = expect(cur, Keys.Transaction, 160, 160);
        value.from = bytes32(msg.data[i:i + 32]);
        value.to = bytes32(msg.data[i + 32:i + 64]);
        value.asset = bytes32(msg.data[i + 64:i + 96]);
        value.meta = bytes32(msg.data[i + 96:i + 128]);
        value.amount = uint(bytes32(msg.data[i + 128:i + 160]));
        cur.i = end;
    }

    // cursor expect*

    function expectAuth(Cursor memory cur, uint cid) internal pure returns (uint deadline, bytes calldata proof) {
        (uint i, uint end) = expect(cur, Keys.Auth, 149, 0);
        if (uint(bytes32(msg.data[i:i + 32])) != cid) revert UnexpectedValue();
        deadline = uint(bytes32(msg.data[i + 32:i + 64]));
        proof = msg.data[i + 64:end];
        cur.i = end;
    }

    function expectAmount(Cursor memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        (uint i, uint end) = expect(cur, Keys.Amount, 96, 96);
        if (bytes32(msg.data[i:i + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[i + 32:i + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function expectBalance(Cursor memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        (uint i, uint end) = expect(cur, Keys.Balance, 96, 96);
        if (bytes32(msg.data[i:i + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[i + 32:i + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function expectMinimum(Cursor memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        (uint i, uint end) = expect(cur, Keys.Minimum, 96, 96);
        if (bytes32(msg.data[i:i + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[i + 32:i + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function expectMaximum(Cursor memory cur, bytes32 asset, bytes32 meta) internal pure returns (uint amount) {
        (uint i, uint end) = expect(cur, Keys.Maximum, 96, 96);
        if (bytes32(msg.data[i:i + 32]) != asset) revert UnexpectedValue();
        if (bytes32(msg.data[i + 32:i + 64]) != meta) revert UnexpectedValue();
        amount = uint(bytes32(msg.data[i + 64:i + 96]));
        cur.i = end;
    }

    function expectCustody(Cursor memory cur, uint host) internal pure returns (AssetAmount memory value) {
        (uint i, uint end) = expect(cur, Keys.Custody, 128, 128);
        if (uint(bytes32(msg.data[i:i + 32])) != host) revert UnexpectedValue();
        value.asset = bytes32(msg.data[i + 32:i + 64]);
        value.meta = bytes32(msg.data[i + 64:i + 96]);
        value.amount = uint(bytes32(msg.data[i + 96:i + 128]));
        cur.i = end;
    }
}
